require 'uri'

class PostAnalyzer
  class << self

    # ORIGINALITY / SOURCING

    def survey_originality(post)
      info={ score: 0 }
      if info[:reblog]=is_reblog(post)
        op=find_op(post)
        info[:op_blog]     =op[:blog]
        info[:op_id]       =op[:id]
        info[:poster_is_op]=poster_is_op(post)
        info[:commented]   =is_commented_reblog(post)
        info[:tagged]      =post['tags'].any?
      else
        info[:poster_is_op]=true
      end
      if   !info[:reblog]
        info[:score]=4
      elsif info[:poster_is_op]
        info[:score]=3
      elsif info[:commented]
        info[:score]=2
      elsif info[:tagged]
        info[:score]=1
      end
      return info.select { |k,v| !!v }
    end

    def has_original_content(post)
      info=survey_originality(post, tags: tags)
      !info[:reblog] || info[:commented] || info[:original_content]
    end

    def poster_is_op(post)
      !is_reblog(post) || find_op(post)[:blog]==post['blog_name']
    end

    def is_reblog(post)
      !!post['reblogged_from_name'] || (post['reblog'] && post['reblog']['tree_html'].length > 0)
    end

    # REVIEW: This may not always be accurate.
    def is_commented_reblog(post)
      is_reblog(post) && post['reblog'] && post['reblog']['comment'] && !post['reblog']['comment'].strip.empty?
    end

    def has_original_content(post, tags: true)
      return true if tags and post['tags'].any?
      !is_reblog(post) || is_commented_reblog(post)
    end

    def is_self_reblog(post)
      post['reblogged_root_name'] == post['blog_name']
    end

    def find_op(post)
      hash = { blog: nil, id: nil }
      if !is_reblog(post)
        hash[:blog] = post['blog_name']
        hash[:id]   = post['id'].to_i
      elsif post['reblogged_root_name']
        hash[:blog] = post['reblogged_root_name']
        hash[:id]   = post['reblogged_root_id'].to_i
      elsif post['trail'] && post['trail'].any? && (op=post['trail'].detect { |item| item['is_root_item'] })
        hash[:blog] = op['blog']['name'], 
        hash[:id]   = op['post']['id'].to_i
      elsif post['source_title'] && post['source_url'].to_s.include?('/post/') && (id=post['source_url'].split('/').reverse.detect {|i| (i.to_i>0) })
        hash[:blog] = post[:source_title]
        hash[:id]   = id.to_i
      end

      unless hash[:blog] && hash[:id]
        warn "Could not determine OP of post #{post['id']} by #{post['blog_name']}"
      end
      return hash
    end

  end # class << self
end