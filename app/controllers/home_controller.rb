class HomeController < ApplicationController

  def index
    @series_category = 'web-series'
    @nsfw_category = 'adult'
    @movie_category = 'movie'
    # most viewed clips
    @random_clips = Clip.order("RANDOM()").limit(5)
    #web-series
    @series_clips = Clip.paginate(:page => params[:page], :per_page => 5)
      .where("clip_category" => @series_category)
      .order('created_at desc')
    #movies
    @movie_clips = Clip.paginate(:page => params[:page], :per_page => 5)
      .where("clip_category" => @movie_category)
      .order('created_at desc')
    #nsfw
    @nsfw_clips = Clip.paginate(:page => params[:page], :per_page => 5)
      .where("clip_category" => @nsfw_category)
      .order('created_at desc')
  end

  def browse_ac
    if params[:search].blank?
      @actresses = Actress.paginate(:page => params[:page], :per_page => 15).order(:first_name)
    else
      @parameter = params[:search].downcase
      @actresses = Actress.paginate(:page => params[:page], :per_page => 15).order(:first_name).where("lower(first_name) LIKE :search", search: "%#{@parameter}%")
    end
  end

  def browse_cl
    if params[:search].blank?
      @clips = Clip.paginate(:page => params[:page], :per_page => 10).order('created_at desc')
    else
      @parameter = params[:search].downcase
      @clips = Clip.paginate(:page => params[:page], :per_page => 10).order('created_at desc').where("lower(movie) LIKE :search", search: "%#{@parameter}%")
    end
  end

  def search_cl
    @series_category = 'web-series'
    @nsfw_category = 'adult'
    @movie_category = 'movie'
    @tag = params[:tag]
    if @tag == @movie_category
      @clips = Clip.paginate(:page => params[:page], :per_page => 10)
        .where("clip_category" => @movie_category)
        .order('created_at desc')
    elsif @tag == @series_category
      @clips = Clip.paginate(:page => params[:page], :per_page => 10)
        .where("clip_category" => @series_category)
        .order('created_at desc')
    elsif @tag == @nsfw_category
      @clips = Clip.paginate(:page => params[:page], :per_page => 10)
        .where("clip_category" => @nsfw_category)
        .order('created_at desc')
    else
      @clips = Clip.paginate(:page => params[:page], :per_page => 10)
       .where("clip_tag1" => @tag)
       .or(Clip.paginate(:page => params[:page], :per_page => 10).where("clip_tag2" => @tag))
       .or(Clip.paginate(:page => params[:page], :per_page => 10).where("clip_tag3" => @tag))
       .or(Clip.paginate(:page => params[:page], :per_page => 10).where("clip_tag4" => @tag))
       .or(Clip.paginate(:page => params[:page], :per_page => 10).where("clip_tag5" => @tag))
       .or(Clip.paginate(:page => params[:page], :per_page => 10).where("movie" => @tag))
       .order('created_at desc')
    end
  end

  def clip
      @clip = Clip.find(params[:id])
      @actress = Actress.find(@clip.actress_id)
      @suggested_clips = Clip.order("RANDOM()").limit(10)
  end

  def actress
      @actress = Actress.find(params[:id])
      #check if record exist
      if Clip.exists?(:actress_id => @actress.id)
        @clip_exists = true
        @clips = Clip.paginate(:page => params[:page], :per_page => 10).where(:actress_id => @actress.id).order('created_at desc')
        #@clips = Clip.where(:actress_id => @actress.id)
      else
        @clip_exists = false
        @clips = Clip.paginate(:page => params[:page], :per_page => 10).where(:actress_id => @actress.id).order('created_at desc')
      end
  end


  def count
    @clip = Clip.find(params[:id])
    @views = @clip.views
    @views = (@views.to_i)+1
    @clip.views = @views
    if @clip.save
      respond_to do |format|
        format.json {render json: {}, status: :ok}
        format.html
      end
    end
  end

  private

    def clip_params
      params.require(:clip).permit(:link_broken, :views)
    end

end
