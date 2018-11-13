module IdentityTijuana
  class API
    def initialize(url = nil, secret = nil)
      @url = url || Settings.tijuana.api.url
      @secret = secret || Settings.tijuana.api.secret

      @client = HTTPClient.new
      @headers = { 'Auth-Token' => @secret }
    end

    def tag_emails(tag, emails)
      @client.post(@url, { tag: tag, :"emails[]" => emails }, @headers)
    end
  end
end
