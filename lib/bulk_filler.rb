class BulkFiller
  def initialize(args)
    @regex = args[:regex]
  end

  def fill
    sorted_reps.each do |rep|
      FormFiller.new(rep, fields_hash_for(rep), "rake").fill_out_form do |rep|
        puts "Please type in the value for the captcha at " + rep + "\n"
        STDIN.gets.strip
      end
    end
  end

  def not_found
    (reps.pluck(:bioguide_id) - congress_defaults.keys).inspect
  end

  private

  def congress_defaults
    @congress_defaults ||= JSON.parse(
      Typhoeus.get(
        "https://raw.githubusercontent.com/EFForg/congress-zip-plus-four/master/legislators.json"
      ).body.gsub(/^define\(|\)$/, '')
    )
  end

  def defaults
    @defaults ||= YAML.load(
      Typhoeus.get(
        "https://raw.githubusercontent.com/unitedstates/contact-congress/master/support/variables.yaml"
      ).body
    )
  end

  def possible_validation
    {
      "$ADDRESS_STREET" => "example_address",
      "$ADDRESS_CITY" => "example_city",
      "$ADDRESS_STATE_POSTAL_ABBREV" => "example_state",
      "$ADDRESS_STATE_FULL" => "example_state"
    }
  end

  def reps
    @reps ||= begin
      bioguide_query = if @regex.blank?
        { bioguide_id: congress_defaults.keys }
      else
        "bioguide_id REGEXP '#{@regex}'"
      end
      CongressMember.where(bioguide_query)
    end
  end

  def sorted_reps
    reps.sort { |a, b| a.has_captcha? ? 1 : -1 }
  end

  def fields_hash_for(rep)
    fields_hash = { }

    %w(zip4 zip5).each do |value|
      title = "$ADDRESS_#{value.upcase}"
      fields_hash[title] = congress_defaults[rep.bioguide_id][value] ||
        defaults[rep.bioguide_id][value] ||
        defaults["$ADDRESS_ZIP4"]["example"]
    end

    rep.required_actions.each do |action|
      value = action.value
      next if fields_hash.keys.include?(value)

      fields_hash[value] = if possible_validation.keys.include? value
        if value == "$ADDRESS_STATE_FULL"
          STATES[congress_defaults[rep.bioguide_id][possible_validation[value]]]
        else
          congress_defaults[rep.bioguide_id][possible_validation[value]]
        end
      elsif defaults.keys.include?(value) && action.options.present?
        options = YAML.load(action.options)
        values = options.is_a?(Hash) ? options.values : options
        values.sample
      end

      fields_hash[value] ||= defaults[value]["example"]
    end

    fields_hash
  end
end
