class EntryController < ApplicationController
  def new
    @entry = Entry.new
  end

  def create
    entry = Entry.new content: params[:content], user: current_user
    if entry.save
      flash[:success] = 'Entry was successfully created.'
      render 'new'
    else
      flash[:error] = 'Entry could not be saved.'
      @errors = entry.errors
      render 'new'
    end
  end

  private

    def entry_params
      params.require(:content)
    end
end
