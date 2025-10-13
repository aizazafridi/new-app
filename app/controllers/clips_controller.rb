require 'json'
require 'fileutils'
require 'net/http'
require 'streamio-ffmpeg'
require 'nokogiri'
require 'dropbox_api'
require 'yaml'

class ClipsController < ApplicationController

  def index
    if params[:search].blank?
      @clips = Clip.paginate(:page => params[:page], :per_page => 15).order('created_at desc')
    else
      @parameter = params[:search].downcase
      @clips = Clip.paginate(:page => params[:page], :per_page => 20).order('created_at desc').where("lower(movie) LIKE :search", search: "%#{@parameter}%")
    end
  end

  def show
    @clip = Clip.find(params[:id])
    @actress = Actress.find_by_id(@clip.actress_id)

  end

  def new
    @clip = Clip.new
  end

  def create

    #get clip url from parameters
    custom_video_link = clip_params[:custom_video_link]

    #name for uploaded image
    #file_name = clip_params[:movie].to_s + clip_params[:id].to_s

    #extract first image from the clip
    image_path = extract_first_frame(custom_video_link)

    # --- GENERATE UNIQUE FILE NAME ---
    # Extract extension (e.g., .jpg, .png, .webp)
    ext = File.extname(image_path)

    # Create unique filename using clip info + random number
    random_suffix = rand(1000..9999)
    movie_name = clip_params[:movie].to_s.parameterize.presence || "clip"
    clip_id = clip_params[:id] || "new"

    file_name = "#{movie_name}_#{clip_id}_#{random_suffix}#{ext}"

    if image_path.blank?
      # If image could not be extracted, save the clip with original params
      @clip = Clip.new(clip_params)
    else

      file_url = upload_image_dropbox(image_path, file_name)

      #Get mediafire session token
      #session = get_token

      #Upload image, get the upload key
      #key = upload_image(session, image_path, file_name)

      #Poll upload, when upload is complete get the quickkey
      #quickkey = poll_upload(session,key)

      #Get uploaded file information
      #file_url = get_file_url(session,quickkey).to_s

      #puts "File URL : #{file_url}"

      #Add file_url to params
      clip_params[:image_src] = file_url
      updated_params = clip_params

      updated_params[:image_src] = file_url

      puts "Clip params : #{updated_params}"

      #Store clip to database
      @clip = Clip.new(updated_params)
    end

    if @clip.save
      redirect_to(clips_path)
    else
      #Redisplay the form
      render('new')
    end

    #Instantiate a new object using form parameters
    #@clip = Clip.new(clip_params)
    #Save the object
    #if @clip.save
      #Redirect to index page
    #  redirect_to(clips_path)
    #else
      #Redisplay the form
    #  render('new')
    #end

  end

  def edit
    @clip = Clip.find(params[:id])
    @actress = Actress.find_by_id(@clip.actress_id)
  end

  def update
    #find the clip
    @clip = Clip.find(params[:id])
    #update the clip
    if @clip.update(clip_params)
      redirect_to(clips_path)
    else
      render("edit")
    end
  end

  def delete
    @clip = Clip.find(params[:id])
  end

  def destroy
    #find the object
    @clip = Clip.find(params[:id])
    #Destroy the object
    if @clip.destroy
      redirect_to(clips_path)
    else
      redirect_to(delete_clip_path(params[:id]))
    end
  end

  def broken_links_index
    @clips = Clip.paginate(:page => params[:page], :per_page => 20).where(:link_broken => true)
  end

  # Method that extracts a png image from a video file and save it
  #def extract_first_frame(video_path)
  #  output_image_path = Rails.root.join('app','assets','images','first_frame.png')
  #  if File.exist?(output_image_path)
      # Delete the file
  #    File.delete(output_image_path)
  #  end
  #  output_image_path = Rails.root.join('app','assets','images','first_frame.png').to_s
  #  movie = FFMPEG::Movie.new(video_path)
  #  # Get the first frame and save it as an image (PNG or JPEG)
  #  frame = movie.screenshot(output_image_path, seek_time: 5)
  #return output_image_path
  #end

  # Method that extracts a png image from a video file and saves it
  def extract_first_frame(video_path)
    output_image_path = Rails.root.join('app', 'assets', 'images', 'first_frame.png')

    begin
      File.delete(output_image_path) if File.exist?(output_image_path)

      movie = FFMPEG::Movie.new(video_path)
      # Get the first frame and save it as an image (PNG or JPEG)
      movie.screenshot(output_image_path.to_s, seek_time: 5)

      return output_image_path.to_s
    rescue => e
      Rails.logger.error "Failed to extract first frame: #{e.message}"
      return ""
    end
  end

  # Method that gets the session token from mediafire account
  # session_token is used in API endpoints for security
  def get_token
    appid = '42511'
    email = 'email@xyz.com'
    passwd = ''
    signature = Digest::SHA1.hexdigest("#{email}#{passwd}#{appid}")
    params = {
      'email' => email,
      'password' => passwd,
      'application_id' => appid,
      'signature' => signature,
      'response_format' => 'json'
    }
    url = URI.parse("https://www.mediafire.com/api/user/get_session_token.php")
    url.query = URI.encode_www_form(params)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(url.request_uri)
    response = http.request(request)
    if response.code.to_i == 200
      json = response.body
      obj = JSON.parse(json)
      session = obj['response']['session_token']
      #puts "Session Token: #{session}"
    else
      puts "HTTP request failed with status code #{response.code}"
    end
    return session
  end

  # Method that uploads image to mediafire
  def upload_image(session_token,file_path, file_name)
    key = ''
    path = 'Imgs'
    # Read the file and get its size
    file_contents = File.read(file_path)
    file_size = file_contents.bytesize
    # Set up the URL
    url = URI.parse("http://www.mediafire.com/api/upload/upload.php?session_token=#{session_token}&path=#{path}")
    # Set up the request
    request = Net::HTTP::Post.new(url.request_uri)
    # Set the headers
    request['x-filename'] = file_name
    request['x-filesize'] = file_size.to_s
    # Set the request body
    request.body = file_contents
    # Make the POST request
    http = Net::HTTP.new(url.host, url.port)
    response = http.request(request)
    # Get the response
    # Process the result
    if response.code.to_i == 200
      result = response.body
      # Parse the XML response
      doc = Nokogiri::XML(result)
      # Extract the value of the <key> element
      key = doc.at('key').text
    else
      puts 'File upload failed.'
    end
    return key
  end

 #Method that polls the current upload and get the quickkey once upload is completed
 # quickkey is used to get file info including view and download links
 def poll_upload(session_token,key)
   quickkey = ''
   # Set up the URL for checking upload status
   url = URI.parse("https://www.mediafire.com/api/upload/poll_upload.php?session_token=#{session_token}&key=#{key}")
   upload_status = -1  # Initialize status to a non-completed value
   while upload_status != 99
     # Make the GET request to check upload status
     http = Net::HTTP.new(url.host, url.port)
     http.use_ssl = true  # Use HTTPS
     response = http.get(url.request_uri)
     if response.code.to_i == 200
       # Parse the Response
       #upload_status = JSON.parse(response.body)
       xml_doc = Nokogiri::XML(response.body)
       upload_status = xml_doc.at('status').text.to_i
       if upload_status == 99
         puts 'upload complete'
         quickkey = xml_doc.at('quickkey').text
       else
         puts 'upload not complete yet, polling again'
         sleep(5)
       end
     else
       puts 'Failed to retrieve upload status. HTTP Status Code: ' + response.code
       break  # Exit the loop on failure
     end
   end
   return quickkey
 end

 # Method that returns the file url
 def get_file_url(session_token,quickkey)
   file_url = ''
   # Set up the URL
   url = URI.parse("https://www.mediafire.com/api/file/get_info.php?quick_key=#{quickkey}&session_token=#{session_token}")
   # Make the GET request
   http = Net::HTTP.new(url.host, url.port)
   http.use_ssl = true  # Use HTTPS
   response = http.get(url.request_uri)
   if response.code.to_i == 200
       xml_doc = Nokogiri::XML(response.body)
       file_url = xml_doc.at('links normal_download').text
   else
     puts 'Failed to retrieve file info.' +response.code
     puts response
   end
   return file_url
 end

 # Method that uploads image to Dropbox and retrieves file url
 def upload_image_dropbox(image_path, file_name)

   access_token= ENV['DROPBOX_ACCESS_TOKEN']

   if access_token.nil? || access_token.strip.empty?
     abort("⚠️ Dropbox access token missing in config.yml")
   end

   # Ensure file exists locally
   unless File.exist?(image_path)
     puts "⚠️ File not found: #{image_path}"
     return nil
   end

   puts file_name
   # Set Dropbox destination filename
   dropbox_dest = "/Images/#{file_name}"

   # --- UPLOAD IMAGE TO DROPBOX ---
   begin
     client = DropboxApi::Client.new(access_token)

     puts "📤 Uploading #{image_path} → Dropbox: #{dropbox_dest} ..."
     file = File.open(image_path, 'rb') { |f| f.read }

     client.upload(dropbox_dest, file, mode: :add)
     puts "✅ Upload complete!"

     # --- CREATE SHARED LINK ---
     begin
       link = client.create_shared_link_with_settings(dropbox_dest)
       share_url = link.url

       # Convert to direct image URL
       direct_url = share_url.gsub('www.dropbox.com', 'dl.dropboxusercontent.com').gsub('?dl=0', '')

       puts "🔗 Direct File URL: #{direct_url}"
       return direct_url

       #puts "🔗 File URL: #{link.url}"
       #return link.url
     rescue DropboxApi::Errors::SharedLinkAlreadyExistsError
       # If the link already exists, retrieve the existing one instead of failing
       links = client.list_shared_links(path: dropbox_dest)
       if links.links.any?
         puts "🔗 Existing File URL: #{links.links.first.url}"
         return links.links.first.url
       else
         puts "⚠️ Couldn't create or find a shared link."
       end
     end

   rescue DropboxApi::Errors::HttpError => e
     puts "❌ Upload failed: #{e.message}"
   rescue DropboxApi::Errors::HttpError => e
     puts "❌ HTTP error: #{e.message}"
   rescue StandardError => e
     puts "⚠️ Error: #{e.message}"
   end

 end


private

  def clip_params
    params.require(:clip).permit(:actress_id, :clip_name, :clip_description, :movie, :release_date, :clip_tag1, :clip_tag2, :clip_tag3, :clip_tag4, :clip_tag5, :clip_category, :clip_src, :image_src, :image_url, :mature, :link_broken, :download_link, :custom_video_link, :stream)
  end

end
