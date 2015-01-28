REQUIRES_WEBKIT = %w[D000563 B000490]
REQUIRES_WATIR = %w[]

CAPTCHA_LOCATIONS = {
  "C000880" => {
    "left" => "267",
    "top" => "1882",
    "width" => "280",
    "height" => "50"
  },
  "C000560" => {
    "left" => "211",
    "top" => "1409",
    "width" => "300",
    "height" => "57"
  },
  "P000608" => {
    "left" => "65",
    "top" => "1450",
    "width" => "300",
    "height" => "57"
  }
}

PLACEHOLDER_VALUES = [
  '$NAME_PREFIX',
  '$NAME_FIRST',
  '$NAME_LAST',
  '$NAME_FULL',
  '$ADDRESS_STREET',
  '$ADDRESS_STREET_2',
  '$ADDRESS_CITY',
  '$ADDRESS_STATE_POSTAL_ABBREV',
  '$ADDRESS_STATE_FULL',
  '$ADDRESS_COUNTY',
  '$ADDRESS_ZIP5',
  '$ADDRESS_ZIP4',
  '$ADDRESS_ZIP_PLUS_4',
  '$PHONE',
  '$PHONE_PARENTHESES',
  '$EMAIL',
  '$TOPIC',
  '$SUBJECT',
  '$MESSAGE',
  '$CAPTCHA_SOLUTION',
  '$CAMPAIGN_UUID',
  '$PERMALINK',
  '$ORG_URL',
  '$ORG_NAME'
]
