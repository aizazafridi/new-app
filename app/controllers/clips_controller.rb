require 'json'

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
    #Instantiate a new object using form parameters
    @clip = Clip.new(clip_params)
    #Save the object
    if @clip.save
      #Redirect to index page
      redirect_to(clips_path)
    else
      #Redisplay the form
      render('new')
    end
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

private

  def clip_params
    params.require(:clip).permit(:actress_id, :clip_name, :clip_description, :movie, :release_date, :clip_tag1, :clip_tag2, :clip_tag3, :clip_tag4, :clip_tag5, :clip_category, :clip_src, :image_url, :mature, :link_broken, :download_link, :custom_video_link, :stream)
  end

end
