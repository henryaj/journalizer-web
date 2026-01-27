module Admin
  class AnalyticsController < ApplicationController
    include AdminAuthorization

    def show
      @period = params[:period] || "7_days"
      @analytics = AnalyticsService.new(period: @period)

      @periods = {
        "7_days" => "Last 7 days",
        "30_days" => "Last 30 days",
        "all_time" => "All time"
      }
    end
  end
end
