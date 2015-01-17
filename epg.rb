require 'ostruct'
require 'httparty'

URL = "http://api.epg.io/2/"
API_KEY = "52d81f925e6ada2472bd7aee72f5e344"
BROADCASTER = "orf1"

class Programme < OpenStruct
    def start_date
        begin
            Time.at(self.programme["start"].to_i)
        rescue
            Time.at(self.start.to_i)
        end
    end

    def end_date
        begin
            Time.at(self.programme["stop"].to_i)
        rescue
            Time.at(self.stop.to_i)
        end
    end

    def get_series
        Series.new(self.series["id"])
    end

end

class Schedule
    attr_accessor :channel
    attr_accessor :date
    attr_accessor :week

    def initialize(channel)
        @channel = channel
    end

    def programmes_from_day(date)
        @date = date.strftime("%Y-%m-%d")
        results = HTTParty.get("#{URL}/schedule/day/#{@date}/#{@channel}?api_key=#{API_KEY}")["programmes"]["#{@channel}"]
        results.collect{|r| Programme.new(r)}
    end

    def programmes_from_week(week,year=Date.now)
        year = year.strftime("%Y")
        @week = week       
        results = HTTParty.get("#{URL}/schedule/week/#{year}/#{week}/#{@channel}?api_key=#{API_KEY}")["programmes"]["#{@channel}"]
        results.collect{|r| Programme.new(r)}
    end    
end

class Series
    attr_accessor :id 

    def initialize(id)
        @id = id
    end

    def summary
        OpenStruct.new(HTTParty.get("#{URL}/series/summary/#{self.id}?api_key=#{API_KEY}"))
    end

    def seasons
        OpenStruct.new(HTTParty.get("#{URL}/series/seasons/#{self.id}?api_key=#{API_KEY}"))
    end

    def season(season)
        OpenStruct.new(HTTParty.get("#{URL}/series/season/#{self.id}/#{season}?api_key=#{API_KEY}"))
    end

    def programmes
        programmes = HTTParty.get("#{URL}/series/programmes/#{self.id}?api_key=#{API_KEY}")
        programmes.collect{|p| Programme.new(p)}
    end
end

#Tryout Stuff
schedule = Schedule.new(BROADCASTER)

# Read in some programmes
programmes = []
start_date = Date.parse("01.01.2015")
end_date = Date.today
(start_date..end_date).each do |date|
    programmes << schedule.programmes_from_day(date)
    puts "Working on day #{date}"
end

#Find out the programmes that have more than one series
results = {}
programmes.flatten.each do |programme|
    series = programme.get_series
    if results[programme.series["id"]] == nil
        puts "(#{programme.start_date.strftime("%d.%m %H:%M")}) Series #{series.summary.title}. # of Programmes #{series.programmes.count}"    
        if series.programmes.count > 1
            results[programme.series["id"]] = {:programme => programme, :series_count => series.programmes.count}        
            puts "Adding to results"
        end
    end
end

#Write down the shows with the most series
CSV.open("#{BROADCASTER}.csv", "wb") do |csv|
    csv << ["Time", "Name of Show", "Number of Runs"]
    results.sort{|a,b| a[1][:series_count]<=> b[1][:series_count]}.reverse.each do |result|
        puts "Working on result"
        csv << [Time.at(result[1][:programme].programme["start"].to_i).strftime("%H:%M"), result[1][:programme].programme["name"], result[1][:series_count]]
    end
end