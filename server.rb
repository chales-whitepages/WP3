require 'rubygems'
require 'sinatra'
require 'twilio-ruby'
require 'httparty'

disable :protection

# put your default Twilio Client name here, for when a phone number isn't given
default_client = "hales"
# Add a Twilio phone number or number verified with Twilio as the caller ID
caller_id   = '(844) 700-9029' #ENV['twilio_caller_id']
account_sid = 'AC3568011c5b1ea77994ed50387219eb8e' #ENV['twilio_account_sid']
auth_token  = '7e3416e57e8aa7437e8f192d8c822ee0' #ENV['twilio_auth_token']
appsid      = 'APcb1860769148402be75b173806b777dd' #ENV['twilio_app_id']

get '/' do
    client_name = params[:client]
    if client_name.nil?
        client_name = default_client
    end

    capability = Twilio::Util::Capability.new account_sid, auth_token
    # Create an application sid at twilio.com/user/account/apps and use it here
    capability.allow_client_outgoing appsid
    capability.allow_client_incoming client_name
    token = capability.generate
    erb :index, :locals => {:token => token, :client_name => client_name, :caller_id=> caller_id}
end



post '/dial' do
    #determine if call is inbound
    number = params[:PhoneNumber]

    response = Twilio::TwiML::Response.new do |r|
        # Should be your Twilio Number or a verified Caller ID
        r.Dial :callerId => caller_id do |d|
            # Test to see if the PhoneNumber is a number, or a Client ID. In
            # this case, we detect a Client ID by the presence of non-numbers
            # in the PhoneNumber parameter.
            if /^[\d\+\-\(\) ]+$/.match(number)
                d.Number(CGI::escapeHTML number)
            else
                d.Client number
            end
        end
    end
    response.text
end

#this will be called from a Twilio voice URL
#for inbound calls, dial the default_client
post '/inbound' do

    from = params[:From]

    response = Twilio::TwiML::Response.new do |r|
        # Should be your Twilio Number or a verified Caller ID
        r.Dial :callerId => from do |d|
            d.Client default_client
        end
    end
    response.text
end

post '/getname' do
    callerId = params[:callerId]
    name = getnamefromaddons(callerId, account_sid, auth_token)
    return name
end

def getnamefromaddons(phone, account_sid, auth_token)
  puts "In Get Name"
  #lookup with twilio addons
  base_uri = "https://lookups.twilio.com/v1/PhoneNumbers/"
  addons =  "?AddOns=whitepages_pro_caller_id&Type=caller-name&Type=carrier"
  auth = {:username => account_sid, :password => auth_token}
  request_url = base_uri + phone + addons

  puts "request #{request_url}"
  response = HTTParty.get(URI.escape(request_url), :basic_auth => auth)

  name = phone #default, if we don't find a name
  puts response
  firstname = " "
  lastname = " "


  #this unfortunate check
  if response['add_ons']['results']['whitepages_pro_caller_identity']['result']['results'][0]['belongs_to'][0]['names']
      puts "got a name"
      firstname = response['add_ons']['results']['whitepages_pro_caller_identity']['result']['results'][0]['belongs_to'][0]['names'][0]['first_name']
      lastname =  response['add_ons']['results']['whitepages_pro_caller_identity']['result']['results'][0]['belongs_to'][0]['names'][0]['last_name']
      name = "#{firstname} #{lastname}"
  end

  if response['caller_name']['caller_name']
      name = response['caller_name']['caller_name']
  end

  carrier = response['add_ons']['results']['whitepages_pro_caller_identity']['result']['results'][0]['carrier']
  line_type = response['add_ons']['results']['whitepages_pro_caller_identity']['result']['results'][0]['line_type']


  locations = response['add_ons']['results']['whitepages_pro_caller_identity']['result']['results'][0]['associated_locations'][0]


  responseobject = {
    :number => phone,
    :phone => phone,
    :name => name,
    :firstname =>  firstname,
    :lastname => lastname,
    :persontype     => "",
    :phonetype  => line_type,
    :carrier  =>  carrier,
    :address  =>  locations['standard_address_line1'] ,
    :city     =>  locations['city'],
    :postal_code => locations['postal_code'],
    :lattitude => locations['lat_long']['latitude'],
    :longitude=> locations['lat_long']['longitude'],
    :state=> locations['state_code'],
    :spamscore=> ""
  }

  return responseobject.to_json

end
