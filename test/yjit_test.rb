require 'zip'

driver_name = 'chromedriver'
Zip::File.open('.chromedriver_linux64.zip') do |zip_file|
  driver = zip_file.get_entry(driver_name)
  f_path = File.join(Dir.pwd, driver.name)
  FileUtils.mkdir_p(File.dirname(f_path)) unless File.exist?(File.dirname(f_path))
  zip_file.extract(driver, f_path)
end