# frozen_string_literal: true

require 'net/http'
require 'set'

module Migration
  class RemoteFiles
    THREADS = 8
    REDIRECTS = 3

    def initialize(rows, fetch: method(:head_of), listing: method(:listing_of))
      @urls = rows.flat_map { |row| row['remote_files'].to_s.split('|').map(&:strip).reject(&:empty?).map { |url| [row['source_identifier'], url] } }
      @fetch = fetch
      @listings = Hash.new { |listings, folder| listings[folder] = listing.call(folder) }
    end

    def problems
      queue = Queue.new
      @urls.reject { |_, url| @listings[folder(url)]&.include?(name(url)) }.each { |pair| queue << pair }
      found = Queue.new
      Array.new(THREADS) do
        Thread.new do
          while (pair = pop(queue))
            problem = check(*pair)
            found << problem if problem
          end
        end
      end.each(&:join)
      list = Array.new(found.size) { found.pop }.sort
      ["BAD REMOTE FILES: #{list.size} of #{@urls.size}", *list.first(20).map { |line| "  #{line}" }] if list.any?
    end

    private

    def pop(queue)
      queue.pop(true)
    rescue ThreadError
      nil
    end

    def check(identifier, url)
      status, type, body = @fetch.call(url)
      return "#{identifier} #{url}: HTTP #{status}#{near_miss(url)}" unless status.to_s.start_with?('2')
      return "#{identifier} #{url}: an HTML page (#{type})" if type.to_s.include?('html') || body.to_s.match?(/<!DOCTYPE html|<html[\s>]/i)

      nil
    rescue StandardError => e
      "#{identifier} #{url}: #{e.class}"
    end

    def near_miss(url)
      match = @listings[folder(url)]&.find { |listed| squash(listed) == squash(name(url)) }
      "; the folder has #{match}" if match
    end

    def squash(file) = file.sub(/\.[^.]+\z/, '').delete('_').downcase
    def folder(url) = url[%r{\A.*/}]
    def name(url) = URI.decode_uri_component(url.split('/').last.to_s)

    def listing_of(folder)
      uri = URI(folder)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 60) do |http|
        http.get(uri.request_uri)
      end
      return unless response.is_a?(Net::HTTPSuccess) && response.body.to_s.include?('<title>Index of ')

      response.body.scan(/href="([^"?\/][^"]*)"/).flatten.to_set { |href| URI.decode_uri_component(href) }
    rescue StandardError
      nil
    end

    def head_of(url, redirects = REDIRECTS)
      uri = URI(url)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 30) do |http|
        http.get(uri.request_uri, 'Range' => 'bytes=0-1023')
      end
      return head_of(URI.join(url, response['location']).to_s, redirects - 1) if response.is_a?(Net::HTTPRedirection) && redirects.positive?

      [response.code, response['content-type'], response.body.to_s[0, 1024]]
    end
  end
end
