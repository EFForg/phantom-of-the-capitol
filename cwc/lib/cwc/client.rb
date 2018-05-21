require "ostruct"
require "json"

require "rest-client"

require "cwc/office"
require "cwc/message"
require "cwc/topic_codes"
require "cwc/bad_request"
require "cwc/fixtures"

module Cwc
  class Client
    attr_accessor :options

    class << self
      def default_client_configuration=(x)
        @default_client_configuration = x
      end

      def default_client_configuration
        @default_client_configuration ||= {}
      end

      def configure(options)
        self.default_client_configuration = options
      end
    end

    # Required options keys
    #   api_key                         String
    #   delivery_agent			String, must match the api key owner
    #   delivery_agent_ack_email	String
    #   delivery_agent_contact_name	String
    #   delivery_agent_contact_email	String
    #   delivery_agent_contact_phone	String, format xxx-xxx-xxxx
    def initialize(options={})
      options = self.class.default_client_configuration.merge(options)
      self.options = {
        api_key: options.fetch(:api_key),
        host: options.fetch(:host),

        delivery_agent: {
          name: options.fetch(:delivery_agent),
          ack_email: options.fetch(:delivery_agent_ack_email),
          contact_name: options.fetch(:delivery_agent_contact_name),
          contact_email: options.fetch(:delivery_agent_contact_email),
          contact_phone: options.fetch(:delivery_agent_contact_phone)
        }
      }
    end

    # Params format
    # {
    #   campaign_id:		String
    #   recipient: {
    #     member_office:		String
    #     is_response_requested:	Boolean	?
    #     newsletter_opt_in:		Boolean	?
    #   },
    #   organization: {
    #     name:		String	?
    #     contact: {
    #       name:	String	?
    #       email:	String	?
    #       phone:	String	?
    #       about:	String	?
    #     }
    #   },
    #   constituent: {
    #     prefix:		String
    #     first_name:		String
    #     middle_name:		String	?
    #     last_name:		String
    #     suffix:		String	?
    #     title:		String	?
    #     organization:		String	?
    #     address:		Array[String]
    #     city:			String
    #     state_abbreviation:	String
    #     zip:			String
    #     phone:		String	?
    #     address_validation:	Boolean	?
    #     email:		String
    #     email_validation:	Boolean	?
    #  },
    #  message: {
    #    subject:			String
    #    library_of_congress_topics:	Array[String], drawn from Cwc::TopicCodes. Must give at least 1.
    #    bills:	{			Array[Hash]
    #      congress:			Integer	?
    #      type_abbreviation:		String
    #      number:			Integer
    #    },
    #    pro_or_con:			"pro" or "con"	?
    #    organization_statement:	String		?
    #    constituent_message:		String		?
    #    more_info:			String (URL)	?
    #  }
    #
    # Use message[:constituent_message] for personal message,
    # or  message[:organization_statement] for campaign message
    # At least one of these must be given
    def create_message(params)
      Cwc::Message.new.tap do |message|
        message.delivery[:agent] = options.fetch(:delivery_agent)
        message.delivery[:organization] = params.fetch(:organization, {})
        message.delivery[:campaign_id] = params.fetch(:campaign_id)

        message.recipient.merge!(params.fetch(:recipient))
        message.constituent.merge!(params.fetch(:constituent))
        message.message.merge!(params.fetch(:message))
      end
    end

    def deliver(message)
      RestClient.post action("/v2/message"), message.to_xml, { content_type: :xml }
      true
    rescue RestClient::BadRequest => e
      raise BadRequest.new(e)
    end

    def validate(message)
      RestClient.post action("/v2/validate"), message.to_xml, { content_type: :xml }
      true
    rescue RestClient::BadRequest => e
      raise BadRequest.new(e)
    end

    def office_supported?(office_code)
      offices.find{ |office| office.code == office_code }.present?
    end

    def required_json(o={})
      Cwc::RequiredJson.merge(o)
    end

    protected

    def action(action)
      host = options[:host].sub(/\/+$/, '')
      action = action.sub(/^\/+/, '')
      "#{host}/#{action}?apikey=#{options[:api_key]}"
    end

    private

    def offices
      if options[:host] =~ %r{^https://cwc.house.gov}
          Cwc::OfficeCodes.map{ |code| Office.new(code) }
      else
        response = RestClient.get action("/offices")
        JSON.parse(response.body).map{ |code| Office.new(code) }
      end
    end
  end
end
