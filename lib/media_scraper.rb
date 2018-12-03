require_relative 'image_finder'
require_relative 'post_analyzer'
require 'fileutils'
require 'faraday'
require 'yaml'

class MediaScraper
  class << self


    # BASIC DOWNLOADING

    def download_files(urls, 
                       dir:, 
                       nested:    true, 
                       sleep_for: 0.33, 
                       overwrite: false, 
                       **params)
      FileUtils.makedirs(dir)
      map = map_fnames(urls, dir: dir, nested: nested)
      File.write(File.join(dir,"fname_map_#{Time.now.to_i}.yml"), map.to_yaml)
      failed=Hash.new
      i=0
      map.each do |url, fname|
        sleep(sleep_for)
        puts "Downloading file #{i+=1} of #{map.count}: #{url}"
        if !download_file(url, fname, overwrite: overwrite)
          failed[url]=fname
        end
      end
      puts "\nFinished downloading #{map.count} files."
      return map
    end

    def download_file(url, filename, overwrite: false)
      if File.exist?(filename) && !overwrite
        puts "File already exists: #{filename}"
        return filename
      end
      FileUtils.makedirs(File.dirname(filename))

      begin
        response = Faraday.get(url)
        File.open(filename, 'wb') { |file| file.write(response.body) }
        return filename
      rescue Faraday::ClientError => e
        warn e.message
        warn "File could not be fetched: #{url}"
        return nil
      end
    end


    # FILENAMES / URL PARSING

    
    # @param [String]    url            Remote url
    # @param [String]    dir: './'      Local directory
    # @param [TrueClass] nested: true   Whether to recreate remote directory
    #                                   structure
    # @return [String]                  Local filename
    def gen_fname(url, dir:, nested: true)
      if nested
        gen_nested_fname(url, dir)
      else
        File.join(dir, File.basename(url))
      end
    end

    # "https://66.media.tumblr.com/8080/tumblr_pg5z5z_r1_500.png"
    # =>
    # "#{dir}/66_media_tumblr_com/8080/tumblr_pg5z5z_r1_500.png"
    # @param  [String] url   Remote url
    # @param  [String] dir   Local directory
    # @return [String]       Local filename
    def gen_nested_fname(url, dir)
      uri = URI(url)
      File.join(dir, uri.host.gsub('.','_'), uri.path)
    end

    def map_fnames(urls, **params)
      urls.map { |url| [url, gen_fname(url, **params)] }.to_h
    end



    # # TODO: Rescue errors, generate and save list of failed downloads.
    # #
    # # check_originality options: 
    # # :no_reblogs    => only parse for images if the post is not a reblog
    # # :poster_is_op  => (default) only parse if the blog in question made 
    # #                   the original post (includes self-reblogs)
    # # :original_body => only parse if the blog contributed to the post 
    # #                   body
    # # :original_body => only parse if the blog contributed to the post 
    # #                   body OR tags
    # #
    # # @param [Array<Hash>] post_hashes
    # # @param [String]      dir:
    # # @param [TrueClass]   nested:            true   Recreate remote dir struct
    # # @param [Float]       sleep_for:         0.33
    # # @param [TrueClass]   check_originality: true 
    # # @param [TrueClass]   overwrite:         false
    # # @return [Hash]                                 URL => local filename map
    # def download_images(post_hashes, dir:, nested: true, sleep_for: 0.33, 
    #                     check_originality: true, overwrite: false)
    #   urls = Array.new
    #   skipped = post_hashes.count
    #   post_hashes.each do |post_hash|
    #     case check_originality
    #     when true, :poster_is_op
    #       next unless poster_is_op(post)
    #     when :no_reblogs
    #       next unless !is_reblog(post)
    #     when :original_body
    #       next unless has_original_content(post, tags: false)
    #     when :original_any
    #       next unless has_original_content(post, tags: true)
    #     end
    #     skipped-=1
    #     urls.concat(ImageFinder.find_in_post(post_hash))
    #   end
    #   urls.uniq!
    #   return nil if urls.empty?
    #   puts "Found #{urls.count} images in #{post_hashes.count} posts."
    #   puts "(Skipped #{skipped} posts due to originality requirements: #{check_originality}"
    #   download_files(urls, dir: dir, nested: nested, sleep_for: sleep_for, overwrite: overwrite)
    # end

    # # TODO: Catch errors, generate and save list of failed downloads.
    # def download_post_images(post_hash, dir:, nested: true, sleep_for: 0.33)
    #   urls = ImageFinder.find_in_post(post_hash)
    #   return nil if urls.empty?
    #   puts "Found #{urls.count} images in post ID #{post_hash['id']}"
    #   download_files(urls, dir: dir, nested: nested, sleep_for: sleep_for)
    # end

  end # class << self
end