require 'erb'
require 'time'
require 'date'
require 'csv'
require 'google/apis/civicinfo_v2'

def clean_zipcode(zip_code)
  zip_code.nil? ? '00000' : zip_code.rjust(5, '0')[0..4]
end

def legislator_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = '***REMOVED***'

  legislators = civic_info.representative_info_by_address(
    address: zipcode,
    levels: 'country',
    roles: ['legislatorUpperBody', 'legislatorLowerBody']
  )
  legislators = legislators.officials

  legislator_names = legislators.map(&:name)
  legislator_names.join(', ')
rescue StandardError
  'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks-#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def clean_phone(number)
  number.gsub!(/[^0-9]/, '')
  if number.length == 10
    number
  elsif number.length == 11 && number[0] == '1'
    number[1..10]
  else
    'Bad number'
  end
end

puts 'Event manager initialized!'

contents = CSV.open('../event_attendees.csv', headers: true, header_converters: :symbol)

template_letter = File.read('./form_letter.erb')
erb_template = ERB.new template_letter

hours = []
weekday = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_raw = row[:homephone]
  phone = clean_phone(row[:homephone])
  date = DateTime.strptime(row[:regdate], '%y/%d/%m %H:%M')

  hours << date.hour
  weekday << date.wday

  puts "#{name} #{phone} #{date}"

  legislators = legislator_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

max = hours.group_by(&:itself).transform_values(&:count)

day_ranking = weekday.group_by(&:itself).transform_values(&:count)
best_day = day_ranking.key(day_ranking.values.max)
day_name = Date::DAYNAMES[best_day - 1]

puts "Most popular time is #{max.key(max.values.max)} and the best day is #{day_name}"
