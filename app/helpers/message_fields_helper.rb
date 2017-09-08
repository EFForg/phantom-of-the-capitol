# coding: utf-8

module MessageFieldsHelper
  def preprocess_message_fields(bio_id, fields)
    fields["$EMAIL"] = fields["$EMAIL"].sub(/\+.*@/, '@')

    fields["$PHONE"] ||= "000-000-0000"
    fields["$ADDRESS_ZIP5"] ||= "00000"
    fields["$ADDRESS_COUNTY"] ||= "Unknown"
    fields["$ADDRESS_STATE_POSTAL_ABBREV"] ||= CongressMember.bioguide(bio_id).try(:state)

    fields["$MESSAGE"] = fields["$MESSAGE"].gsub(/\d+\s*%/){ |m| "#{m[0..-2]} percent" }
    fields["$MESSAGE"] = fields["$MESSAGE"].gsub('\w*&\w*', ' and ')

    fields["$MESSAGE"] = fields["$MESSAGE"].gsub("’", "'")
    fields["$MESSAGE"] = fields["$MESSAGE"].gsub("“", '"').gsub("”", '"')

    fields["$MESSAGE"] = fields["$MESSAGE"].gsub("—", '-')
    fields["$MESSAGE"] = fields["$MESSAGE"].gsub("–", '-')

    fields["$MESSAGE"].gsub!('--', '-') while fields["$MESSAGE"] =~ /--/

    fields["$MESSAGE"] = fields["$MESSAGE"].gsub(/[^-+\s\w,.!?$@:;()#&_\/"']/, '')
  end
end
