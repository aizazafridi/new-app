require 'json'
require 'fileutils'
require 'net/http'
require 'streamio-ffmpeg'
require 'nokogiri'

class CloudClipsController < ApplicationController
  before_action :set_cloud_clip, only: %i[ show edit update destroy ]

  # GET /cloud_clips or /cloud_clips.json
  def index
    #@cloud_clips = CloudClip.all
    @tag = params[:tag]
    if params[:search].blank?
      @cloud_clips = CloudClip.paginate(:page => params[:page], :per_page => 15).order('created_at desc')
    else
      @parameter = params[:search].downcase
      @cloud_clips = CloudClip.paginate(:page => params[:page], :per_page => 10)
       .where("description" => @tag)
       .order('created_at desc')
    end
  end

  # GET /cloud_clips/1 or /cloud_clips/1.json
  def show
    @cloud_clip = CloudClip.find(params[:id])
  end

  # GET /cloud_clips/new
  def new
    @cloud_clip = CloudClip.new
  end

  # GET /cloud_clips/1/edit
  def edit
  end

  # POST /cloud_clips or /cloud_clips.json
  def create
    #get clip url from parameters
    custom_video_link = cloud_clip_params[:custom_video_link]

    #name for uploaded image
    file_name = cloud_clip_params[:description].to_s

    #extract first image from the clip
    image_path = extract_first_frame(custom_video_link)

    #Get mediafire session token
    session = get_token

    #Upload image, get the upload key
    key = upload_image(session, image_path, file_name)

    #Poll upload, when upload is complete get the quickkey
    quickkey = poll_upload(session,key)

    #Get uploaded file information
    file_url = get_file_url(session,quickkey).to_s

    puts "File URL : #{file_url}"

    #Add file_url to params
    #clip_params[:image_src] = file_url
    updated_params = cloud_clip_params

    updated_params[:image_src] = file_url

    puts "Clip params : #{updated_params}"

    #Store clip to database
    @cloud_clip = CloudClip.new(updated_params)

    if @cloud_clip.save
      redirect_to(cloud_clips_path)
    else
      #Redisplay the form
      render('new')
    end
  end

  # PATCH/PUT /cloud_clips/1 or /cloud_clips/1.json
  def update
    respond_to do |format|
      if @cloud_clip.update(cloud_clip_params)
        format.html { redirect_to cloud_clip_url(@cloud_clip), notice: "Cloud clip was successfully updated." }
        format.json { render :show, status: :ok, location: @cloud_clip }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @cloud_clip.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /cloud_clips/1 or /cloud_clips/1.json
  def destroy
    @cloud_clip.destroy

    respond_to do |format|
      format.html { redirect_to cloud_clips_url, notice: "Cloud clip was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # Method that extracts a png image from a video file and save it
  def extract_first_frame(video_path)
    output_image_path = Rails.root.join('app','assets','images','first_frame.png')
    if File.exist?(output_image_path)
      # Delete the file
      File.delete(output_image_path)
    end
    output_image_path = Rails.root.join('app','assets','images','first_frame.png').to_s
    movie = FFMPEG::Movie.new(video_path)
    # Get the first frame and save it as an image (PNG or JPEG)
    frame = movie.screenshot(output_image_path, seek_time: 20)
    return output_image_path
  end

  def get_token
    appid = '42511'
    email = 'bolly.skin.2021@gmail.com'
    passwd = 'Mm15qewleep,'
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
    path = 'Imgs2'
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_cloud_clip
      @cloud_clip = CloudClip.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def cloud_clip_params
      params.require(:cloud_clip).permit(:category, :description, :custom_video_link, :image_src)
    end
end
