module HomeHelper
  # FIXME: inner_api_helperと重複してる
  class BitbucketAPIException < Exception
  end

  BREAKPOINTS = ["lg", "md", "sm", "xs"]

  def create_bitbucket_repository(name)
    user = ENV["BITBUCKET_USER"]
    pass = ENV["BITBUCKET_PASSWORD"]

    req = Net::HTTP::Post.new("/2.0/repositories/snapsaver/#{name}", {"Content-Type" => "application/json"})
    req.body = {"scm" => "git", "is_private" => "false", "fork_policy" => "allow_forks"}.to_json
    req.basic_auth(user, pass)

    sock = Net::HTTP.new("api.bitbucket.org", 443)
    sock.use_ssl = true
    sock.verify_mode = OpenSSL::SSL::VERIFY_NONE
    #sock.set_debug_output $stderr

    sock.start do |http|
      response = http.request(req)
      raise BitbucketAPIException.new if response.code != '200'
      response.body
    end
  end
end
