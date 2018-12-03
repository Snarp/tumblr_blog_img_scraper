require 'json'
require 'fileutils'
require_relative 'json_scraper'
require_relative 'image_finder'
require_relative 'media_scraper'

class Scraper
  attr_accessor :base_dir, :media_dir, :sleep_for, 
                :download_images, :filter_downloads, :postprocess, 
                :blog_defaults

  # @param [String]    consumer_key:                 Tumblr API V2 credentials
  # @param [String]    consumer_secret:    nil       Tumblr API V2 credentials
  # @param [String]    oauth_token:        nil       Tumblr API V2 credentials
  # @param [String]    oauth_token_secret: nil       Tumblr API V2 credentials
  # @param [TrueClass] postprocess:        true      Whether to postprocess scraped JSON files (to find image download URLs, etc)
  # @param [TrueClass] download_images:    true      Whether to download images
  # @param [String]    base_dir:           'scraped' Where to save JSON files
  # @param [String]    media_dir:          nil       Where to save media
  # @param [TrueClass] filter_downloads:     :poster_is_op      Whether to download only media meeting originality specified originality requirements
  # @param [TrueClass] media_dir_structure:  :recreate_remote  Whether to recreate remote path structure when downloading media
  # @param [Float]     sleep_for:            0.33    Interval between requests
  # @param [Hash]      **blog_defaults               Tumblr API V2 arguments
  def initialize(consumer_key:, 
                 consumer_secret:     nil, 
                 oauth_token:         nil, 
                 oauth_token_secret:  nil, 
                 postprocess:         true, 
                 download_images:     true, 
                 base_dir:            'scraped', 
                 media_dir:           nil, 
                 filter_downloads:    :poster_is_op, 
                 media_dir_structure: :recreate_remote, 
                 sleep_for:           0.33, 
                 **blog_defaults)
    @postprocess,@download_images,@base_dir,@media_dir,@filter_downloads,@media_dir_structure,@sleep_for,@blog_defaults=postprocess,download_images,base_dir,media_dir,filter_downloads,media_dir_structure,sleep_for,blog_defaults
    @media_dir = File.join(@base_dir, '_media') unless @media_dir
    @credentials = { consumer_key: consumer_key, consumer_secret: consumer_secret, oauth_token: oauth_token, oauth_token_secret: oauth_token_secret }
  end


  # --------
  # SCRAPING
  # --------


  # TODO: Make it possible to scrape a blog based on unique blog ID#, to account for username changes.
  # 
  # filter_downloads options: 
  # :no_reblogs    => only process for images if the post is not a reblog
  # :poster_is_op  => (default) only parse if the blog in question made 
  #                   the original post (includes self-reblogs)
  # :original_body => only parse if the blog contributed to the post 
  #                   body
  # :original_body => only parse if the blog contributed to the post 
  #                   body OR tags
  # 
  # @param [String]    blog
  # @param [TrueClass] download_images:  @download_images        Whether to download images
  # @param [TrueClass] filter_downloads: @filter_downloads 
  # @param [TrueClass] postprocess: @postprocess   Whether to postprocess scraped json (to find image download URLs, etc)
  # @param [String]    dir:         nil
  # @param [String]    media_dir:   @media_dir     Where to save images/media
  # @param [String]    base_dir:    @base_dir
  # @param [Float]     sleep_for:   @sleep_for
  # @param [Hash]      **tumblr_api_args           Tumblr API V2 arguments
  # @return [Hash]                                 { dir:   {JSON save dir}, 
  #                                                  pages: {# pages saved}  }
  def scrape_blog(blog, 
                  download_images:  @download_images, 
                  filter_downloads: @filter_downloads, 
                  postprocess:      @postprocess, 
                  dir:              nil, 
                  media_dir:        @media_dir, 
                  **tumblr_api_args)
    puts "\nPreparing to scrape Tumblr blog #{blog}...\n"
    dir = File.join(@base_dir, blog) unless dir

    scraped = scrape_blog_json(blog, dir: File.join(dir,'json'), **tumblr_api_args)
    timestamp = scraped[:init_scrape].strftime('%Y%m%d_%H%M%S')
    File.write(File.join(dir, "scraped_#{timestamp}.yml"), scraped.to_yaml)

    if download_images
      processed = download_archive_imgs(File.join(dir,'json'), media_dir: media_dir, filter_downloads: filter_downloads, sleep_for: @sleep_for)
    elsif postprocess
      processed = postprocess_json(File.join(dir,'json'), analyze_originality: !!filter_downloads)
    end

    # Rewrite meta file with new data.
    if processed
      File.write(File.join(dir, "processed_#{timestamp}.yml"), processed.to_yaml)
    end

    return { scraping: scraped, processing: processed }
  end

  # Scrapes all pages from a Tumblr blog using JSON API V2, without parsing to
  # hash or otherwise processing.
  # 
  # @param [String]  blog
  # @param [String]  dir:       nil          Default is {base_dir}/{blog}
  # @param [Float]   sleep_for: @sleep_for
  # @param [Hash]    **tumblr_api_args       Tumblr API V2 arguments.
  # @return [Hash]                           { dir:   {JSON save dir}, 
  #                                            pages: {# pages saved}  }
  def scrape_blog_json(blog, dir:, **tumblr_api_args)
    FileUtils.makedirs(dir)
    json_scraper.get_blog(blog, dir: dir, sleep_for: @sleep_for, **@blog_defaults.merge(tumblr_api_args))
  end

  # @return [JsonScraper]
  def json_scraper
    JsonScraper.new(api_key: @credentials[:consumer_key])
  end


  # POSTPROCESSING

  # TODO: Implement other media_dir_structure options. Currently only using recreate_remote directory structure.
  def download_archive_imgs(dir, 
                            filter_downloads: @filter_downloads, 
                            media_dir:        @media_dir, 
                            **media_scraper_params)
    processed = postprocess_json(dir, analyze_originality: !!filter_downloads)

    puts "processed: #{processed}"

    img_urls     = Array.new
    posts_w_imgs = 0
    i            = 0
    processed[:posts_info].each do |id, post|
      next unless post[:img_urls]
      posts_w_imgs+=1

      orig=post[:originality]
      if !filter_downloads || !orig[:reblog]
        img_urls.concat(post[:img_urls])
        i+=1
      elsif filter_downloads==:no_reblogs
        next
      elsif orig[:poster_is_op]
        img_urls.concat(post[:img_urls])
        i+=1
      elsif filter_downloads==:original_body && orig[:commented]
        img_urls.concat(post[:img_urls])
        i+=1
      elsif filter_downloads==:original_any && orig[:tagged]
        img_urls.concat(post[:img_urls]) 
        i+=1
      end
    end
    img_urls.uniq!

    puts "Found in archive #{dir}: #{img_urls.count} unique image URLs, associated with #{i} unique posts."
    puts "(Posts excluded due to originality requirements (#{filter_downloads}): #{posts_w_imgs-i})\n"

    MediaScraper.download_files(img_urls, dir: dir, nested: true, sleep_for: @sleep_for, **media_scraper_params)
    return processed
  end

  # TODO: Conversion to database/HTML/Jekyll.
  # TODO: Add to output: post count, unique blog ID#, earliest post timestamp, latest post timestamp, blog last updated timestamp.
  # 
  # Processes a directory contained a blog's scraped JSON archive.
  # 
  # @param [String]         dir
  # @param [TrueClass]      analyze_originality: @filter_downloads
  # @param [Hash]           **p
  # @return [Array<String>]                        List of image URLs
  def postprocess_json(dir, analyze_originality: @filter_downloads)
    json_files = Dir[File.join(dir, '*.json')].sort
    puts "\nPreparing to scan #{json_files.count} JSON files in dir #{dir}...\n\n"

    # Analyzing posts
    init_time   = Time.now
    posts       = Hash.new
    total_posts = 0
    i           = 0
    json_files.each do |fname|
      puts "Scanning JSON file #{i+=1} of #{json_files.count}: #{fname}"
      JSON::parse(File.read(fname))['response']['posts'].each do |post|
        # Duplicated posts are likely, given that we're postprocessing JSON 
        # fetched without using the :before argument; however, a LOT of 
        # duplicated posts could indicate a download/parsing problem.
        if posts[post['id']]
          warn "Already processed post ID ##{post['id']}"
          next
        end
        total_posts+=1
        posts[post['id']]=Hash.new

        if analyze_originality
          posts[post['id']][:originality]=PostAnalyzer.survey_originality(post)
        end

        urls=ImageFinder.find_in_post(post)
        posts[post['id']][:img_urls]=urls if urls.any?
      end
    end
    puts "\nTotal JSON files parsed: #{i}"
    puts "Total posts parsed: #{total_posts}\n"

    blog_info = JSON::parse(File.read(json_files[0]))['response']['blog']
    keys = posts.keys.sort
    blog_info[:oldest_id] = keys.first
    blog_info[:newest_id] = keys.last
    blog_info[:oldest_id_timestamp] = posts[blog_info[:oldest_id]]['timestamp']
    blog_info[:newest_id_timestamp] = posts[blog_info[:newest_id]]['timestamp']

    return { init_process: init_time, end_process: Time.now, total_posts: total_posts, blog_info: blog_info, posts_info: posts }
  end

end # class Scraper