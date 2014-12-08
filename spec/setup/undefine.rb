# Required to clear classes defined in `load 'setup/*.rb'` to make subsequent `load 'setup/*.rb'` to work correctly.
%i| Article Comment AuthorProfile Author Tag Book |.each do |class_name|
  if Object.const_defined?(class_name)
    Object.send(:remove_const, class_name)
    STDERR.puts "Undefined #{class_name}"
  end
end
