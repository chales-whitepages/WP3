require 'rubygems'
require 'sinatra'
require 'twilio-ruby'
require 'httparty'
require 'json'

disable :protection

# put your default Twilio Client name here, for when a phone number isn't given
default_client = "hales"
# Add a Twilio phone number or number verified with Twilio as the caller ID
caller_id   = '(844) 700-9029' #ENV['twilio_caller_id']
account_sid = 'AC3568011c5b1ea77994ed50387219eb8e' #ENV['twilio_account_sid']
auth_token  = '7e3416e57e8aa7437e8f192d8c822ee0' #ENV['twilio_auth_token']
appsid      = 'APcb1860769148402be75b173806b777dd' #ENV['twilio_app_id']
api_key     = '76a12eda22c06e1428a069f8b7feedfc' #ENV['whitepages_api_key']

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
    #addOnJsonOption = params[:AddOns]
    #parsed = JSON.parse(addOnJsonOption)
    #puts parsed['status']
    #puts "Complete Inbound"
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
    addOnJsonOption = params[:AddOns]

    puts addOnJsonOption
    puts "Get Name Complete"
    name = getnamefromwhitepages(callerId, addOnJsonOption, api_key)
    puts "Gather Info Complete"
    return name
end


def getnamefromwhitepages (phone, addOnJson, api_key)

   base_uri = "http://proapi.whitepages.com/"
   version = "2.0/"

   #the whitepagesobject will be returned with availible info.. bare minimum phone
   whitepagesobject = {
    :number => phone,
    :name => phone,
    :firstname => "",
    :lastname => "",
    :persontype     => "",
    :phonetype  => "",
    :carrier  =>  "",
    :address  =>  "" ,
    :city     =>  "",
    :postal_code => "",
    :lattitude => "",
    :longitude=> "",
    :state_code=> "",
    :replevel=> "" }

  #request_url = base_uri + version + "phone.json?phone="+ phone  +"&api_key="+api_key
  #response = HTTParty.get(URI.escape(request_url))

  result = addOnJson['results']['whitepages_pro_calller_id']['result']['results'] #get the first result assume it alsway a phone

  if result
    whitepagesobject[:phonetype] = result[0]['line_type']
    whitepagesobject[:carrier]   = result[0]['carrier']
    # whitepagesobject[:replevel]  = dictionarykeyphone['reputation']['level']

    if result['belongs_to'][0]

      whitepagesobject[:persontype]= result[0]['belongs_to'][0]['id']['type']

      belongstoKey = results[0]['belongs_to'][0]['id']['key']
      puts "belongstoKey = #{belongstoKey}"

      # belongstoObject = response['dictionary'][belongstoKey]  #retrieve
      if belongstoObject
        if whitepagesobject[:persontype] == "Person"
          whitepagesobject[:firstname] = results[0]['belong_to'][0]['names'][0]['first_name']  #TODO: This can error if there is no first_name
          whitepagesobject[:lastname]  = results[0]['belong_to'][0]['names'][0]['last_name']
          whitepagesobject[:name] = "#{whitepagesobject[:firstname]} #{whitepagesobject[:lastname]}"
        elsif whitepagesobject[:persontype] == "Business"
          whitepagesobject[:name]  = results[0]['belong_to'][0]['name']
        end

      end

    end


    locationKey = results[0]['associated_locations'][0]['id']['key']
    # locationObject = response['dictionary'][locationKey]  #retrieve best location

    if locationObject
      whitepagesobject[:addressLine1] = results[0]['associated_locations'][0]['standard_address_line1']
      whitepagesobject[:addressLine2] = results[0]['associated_locations'][0]['standard_address_line2']
      whitepagesobject[:address] = "#{whitepagesobject[:addressLine1]} #{whitepagesobject[:addressLine2]}"
      whitepagesobject[:city] = results[0]['associated_locations'][0]['city']
      whitepagesobject[:state_code] = results[0]['associated_locations'][0]['state_code']
      whitepagesobject[:postal_code] = results[0]['associated_locations'][0]['postal_code']
      whitepagesobject[:lattitude] = results[0]['associated_locations'][0]['lat_long']['latitude']
      whitepagesobject[:longitude] = results[0]['associated_locations'][0]['lat_long']['longitude']
    end

  end
  return whitepagesobject.to_json

end
