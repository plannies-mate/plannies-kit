module Protection
  class ProtectionDetector
    def analyze(url, timeout_seconds: 30)
      results = { url: url, timestamp: Time.now.iso8601 }

      uri = URI(url)
      analyze_dns(uri, results)
      analyze_headers(uri, results, timeout_seconds)

      results
    rescue => e
      results[:error] = "#{e.class}: #{e.message}"
      results[:status] = :error
      results
    end

    private

    def analyze_dns(uri, results)
      Timeout.timeout(10) do
        ip = Resolv.getaddress(uri.host)
        results[:ip] = ip

        whois = Whois.whois(ip)
        results[:hosting_provider] = extract_hosting_info(whois)
      end
    rescue Timeout::Error
      results[:dns_error] = "DNS lookup timeout"
    end

    def analyze_headers(uri, results, timeout_seconds)
      Timeout.timeout(timeout_seconds) do
        response = Net::HTTP.start(uri.host, uri.port,
                                   use_ssl: uri.scheme == 'https',
                                   open_timeout: 10,
                                   read_timeout: 10
        ) do |http|
          http.head(uri.path)
        end

        results.merge!(extract_protection_info(response))
      end
    rescue Timeout::Error
      results[:error] = "Timeout after #{timeout_seconds}s"
      results[:status] = :timeout
    rescue OpenSSL::SSL::SSLError => e
      results[:error] = "SSL Error: #{e.message}"
      results[:status] = :ssl_error
    rescue Net::HTTPForbidden
      results[:error] = "Access Forbidden (403)"
      results[:status] = :forbidden
    end

    def extract_protection_info(response)
      {
        status: response.code.to_i,
        server: response['server'],
        cdn: detect_cdn(response),
        protection: detect_protection_headers(response),
        rate_limits: extract_rate_limits(response)
      }
    end

    # The rest of the helper methods (detect_cdn, etc) would go here...
  end
end
