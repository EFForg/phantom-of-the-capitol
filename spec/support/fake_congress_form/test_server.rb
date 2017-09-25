require 'sinatra/base'

TESTSERVER = Sinatra.new do
  set :logging, false

  get '/' do
    erb :index
  end

  get '/with-captcha' do
    @captcha = true
    erb :index
  end

  post '/contact-result' do
    req_fields = ["prefix", "first-name", "last-name", "address", "city", "zip", "email", "message"]
    valid_req = true
    req_fields.each do |r|
      if params[r].nil? or params[r].length == 0
        valid_req = false
      end
    end
    unless params["captcha"].nil?
      valid_req = false unless params["captcha"] == "placeholder"
    end
    if valid_req
      body "Thank you for your feedback!"
    else
      status 500
      body "Not all required fields have been filled"
    end
  end
end
