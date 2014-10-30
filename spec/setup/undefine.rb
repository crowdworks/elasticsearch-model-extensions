if defined? ::Article
  Object.send(:remove_const, :Article)
end

if defined? ::Comment
  Object.send(:remove_const, :Comment)
end
