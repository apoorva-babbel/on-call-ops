# frozen_string_literal: true

require 'json'
require 'uri'
require 'net/http'
require 'date'

SCHEDULE_FILE = 'lib/schedule.json'
VIEW_FILE = 'index.html'

# Test comment 3
def pull_pg_schedule(schedule_id:)
  response = get_response(schedule_id: schedule_id)
  puts response
  mask_results(response[:oncalls][0][:user][:summary])
end

def mask_results(str)
  str.gsub(/.(?=.{4})/, '#')
end

def get_response(schedule_id:)
  uri = URI("https://api.pagerduty.com/oncalls?schedule_ids[]=#{schedule_id}")
  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Token token=#{ENV['PD_TOKEN']}"
  request['Accept'] = "application/vnd.pagerduty+json;version=2"

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end
  JSON.parse(response.body, { symbolize_names: true })
end

def insert_schedule(team1:, team2:, team3:)
  data = JSON.parse(File.read(SCHEDULE_FILE))

  new_schedule = {
    "team1": team1,
    "team2": team2,
    "team3": team3,
    "week": Date.today.strftime('%V')
  }

  data << new_schedule
  updated_json_content = JSON.pretty_generate(data)

  save_to_json(updated_json_content)
end

def save_to_json(json_string)
  File.open(SCHEDULE_FILE, 'w') do |f|
    f.write(json_string)
  end
end

def update_og_headers
  json_string = JSON.parse(File.read(SCHEDULE_FILE), { symbolize_names: true })
  description = create_description(json_string.last)
  html_content = File.read(VIEW_FILE)
  new_meta_tag = "<meta property='og:description' content='#{description}'"
  modified_content = html_content.gsub(/<meta property='og:description' content='[^"]*'/, new_meta_tag)
  File.write(VIEW_FILE, modified_content)
end

def create_description(hash)
  [
    "B2B Platform: #{hash[:team1]}",
    "B2B Data Insights: #{hash[:team2]}",
    "B2B Enterprise: #{hash[:team3]}"
  ].join('; ')
end

def clear_schedule
  data = JSON.parse(File.read(SCHEDULE_FILE))
  current_length = data.length
  desired_length = 11
  data.shift(current_length - desired_length) if current_length > desired_length
  save_to_json(JSON.pretty_generate(data))
end

user_team1 = pull_pg_schedule(schedule_id: "PGONDG5")
user_team2 = pull_pg_schedule(schedule_id: "P0QYXI3")
user_team3 = pull_pg_schedule(schedule_id: "PWAVTID")

clear_schedule
insert_schedule(team1: user_team1, team2: user_team2, team3: user_team3)
update_og_headers
