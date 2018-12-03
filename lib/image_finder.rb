require 'oga'

# Class ImageFinder provides functions for use in locating image URLs embedded in Tumblr posts.
# @author Snarp <snarp@snarp.work>

class ImageFinder
  class << self

    # @param  [Hash]           post_hash
    # @return [Array<String>]
    def find_in_post(post_hash)
      urls = Array.new
      urls.concat find_in_photoset(post_hash)
      urls.concat find_in_body(post_hash)
      urls.push   post_hash['album_art']

      urls.uniq.select { |url| !!url && !url.empty? }
    end

    # @param  [Hash]           post_hash
    # @return [Array<String>]
    def find_in_photoset(post_hash)
      return [] unless photoset = post_hash['photos']
      urls = photoset.map { |photo| photo['original_size']['url'] }
      urls.uniq.select { |src| !!src && !src.empty? }
    end


    # PARSING API FIELDS CONTAINING HTML

    # TODO:   Make sure that this checks ALL fields which might contain HTML.
    # REVIEW: Regex search?
    # 
    # @param  [Hash]           post_hash
    # @return [Array<String>]
    def find_in_body(post_hash)
      # REVIEW: Need to double-check that this is an accurate list of all 
      #         fields that can contain user-generated HTML.
      ['body', 'caption', 'text', 'source'].map do |name|
        if (html=post_hash[name]).is_a?(String)
          find_in_html_str(html)
        end
      end.flatten.uniq.select { |src| !!src && !src.empty? }
    end

    # @param  [String]         html_str
    # @return [Array<String>]
    def find_in_html_str(html_str)
      return [] unless html_str.include?('img')
      doc = Oga.parse_html(html_str.force_encoding('UTF-8'))
      doc.css('img').attr('src').select { |src| !!src }.map do |src|
        src.to_s
      end
    end

  end # class << self
end