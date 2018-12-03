WHY IS THIS THING IN ANY WAY BETTER THAN ANY OTHER OPTION
---------------------------------------------------------

It is worse in nearly every sense except for one: it grabs all the JSON without parsing FIRST (meaning that it's relatively fast compared to the tumblr_client gem or etc).

It then optionally lets you parse all that scraped JSON and extract the URLs of all images, INCLUDING those within the post body, and download all of them.

Downloads can also be filtered (clumsily) by originality: by default, it's set only download images from posts for which the blog in question is the OP. You can set it to grab all images in the settings.yml file.

I wrote this script because these features specifically were important to me, and it has no other especially useful or unique features.

HOW TO USE
----------

1) Install Ruby. Sorry. This is not going to be fun if you have not yet installed Ruby.

2) Rename 'settings_default.yml' to 'settings.yml' to change any settings you might want to change.

3) Rename 'credentials_yml_env' to 'credentials.yml.env' and input your Tumblr API V2 credentials. You get consumer key and consumer secret by going through the 'register an application' process here:

<https://www.tumblr.com/oauth/apps>

and once you've done so, you can get the OAuth token and OAuth token secret by returning to the page and clicking 'explore API' to access the console.

I'm not going to go into more detail on this right now because I am sleep-deprived and have forgotten to drink water/how to drink water. I am sorry about this. Someone else do it, please.

4) Syntax:

    ruby scrape_blog.rb BLOG_NAME

For example:

    ruby scrape_blog.rb demo
    ruby scrape_blog.rb staff
    ruby scrape_blog.rb neuromanceler

SNARP'S FUCKEN TODO
-------------------
  - Scrape videos, audio
  - Download-error catching
  - Implement alternative media structure to recreate_remote, because Windows is Windows
  - Post-process JSON files to database/HTML/Jekyll/Wordpress
  - Output log to file
  - Sit on floor some