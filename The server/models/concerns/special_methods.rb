# app/models/concerns/special_methods.rb
module SpecialMethods
  extend ActiveSupport::Concern

  def dump_fixture
    fixture_file = "#{Rails.root}/test/fixtures/#{self.class.table_name}.yml"
    File.open(fixture_file, "a+") do |f|
      f.puts({ "#{self.class.table_name.singularize}_#{id}" => attributes }.
        to_yaml.sub!(/---\s?/, "\n"))
    end
  end
#  def foo
#     "hi its foo"
#  end
end



