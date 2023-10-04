class ActressesController < ApplicationController

  def index
    if params[:search].blank?
      @actresses = Actress.paginate(:page => params[:page], :per_page => 30).order(:first_name)
    else
      @parameter = params[:search].downcase
      @actresses = Actress.paginate(:page => params[:page], :per_page => 30).order(:first_name).where("lower(first_name) LIKE :search", search: "%#{@parameter}%")
    end
  end

  def show
    @actress = Actress.find(params[:id])
    @clips = Clip.where(:actress_id => "#{@actress.id}")

  end

  def new
    @actress = Actress.new
  end

  def create
    #Instantiate a new object using form parameters
    @actress = Actress.new(actress_params)
    #Save the object
    if @actress.save
      #Redirect to index page
      redirect_to(actresses_path)
    else
      #Redisplay the form
      render('new')

    end
  end

  def edit
    @actress = Actress.find(params[:id])
  end

  def update
    #Find an object using params
    @actress = Actress.find(params[:id])
    #Update the object
    if @actress.update(actress_params)
      #Redirect to index page
      redirect_to(actresses_path(@actress))
    else
      #Redisplay the form
      render('edit')

    end
  end

  def delete
    @actress = Actress.find(params[:id])
  end

  def destroy
    #find the object
    @actress = Actress.find(params[:id])
    #destroy the object
    @actress.destroy
    #Redirect to index page
    redirect_to(actresses_path)
  end

  private
  def actress_params
    params.require(:actress).permit(:first_name, :last_name, :image_url, :image_path, :title, :description, :cloud_image)
  end

end
