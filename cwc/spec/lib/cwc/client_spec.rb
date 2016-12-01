
require "ostruct"

require "spec_helper"
require "cwc/client"

describe Cwc::Client do
  let(:cwc) { Cwc::Client.new(cwc_client_params) }

  describe "#create_message" do
    it "should pass through delivery_agent options" do
      message = cwc.create_message(cwc_message_params)
      expect(message.delivery[:agent]).to eq(cwc.options[:delivery_agent])
    end
  end

  describe "#deliver" do
    it "should POST the message to /v2/message as XML, returning true on success" do
      message = double(to_xml: double("Cwc::Message#to_xml"))

      expect(RestClient).to receive(:post) do |url, body, headers|
        expect(url).to match(%r{^https://cwc\.house\.gov\.example\.org/v2/message\?apikey=})
        expect(body).to eq(message.to_xml)
        expect(headers[:content_type]).to eq(:xml)
        double(code: 200)
      end

      expect(cwc.deliver(message)).to be_truthy
    end

    it "should raise Cwc::BadRequest on failure" do
      message = double(to_xml: nil)

      expect(RestClient).to receive(:post) do
        exception = Class.new(RestClient::BadRequest) do
          def response
            OpenStruct.new(body: "")
          end
        end

        raise exception.new
      end

      expect{ cwc.deliver(message) }.to raise_error(Cwc::BadRequest)
    end
  end
end
