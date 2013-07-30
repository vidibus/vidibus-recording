# Helper for stubbing time. Define String to be set as Time.now.
#
# Basic usage:
#   stub_time('01.01.2010 14:00')
#   stub_time(2.days.ago)
#
# You may also provide a block that will be executed within the given time:
#   stub_time(2.days.ago) do
#     puts Time.now
#   end
#
def stub_time(string = nil, &block)
  @now ||= Time.now
  string ||= Time.now.to_s(:db)
  now = Time.parse(string.to_s)
  stub(Time).now {now}
  if block_given?
    yield
    stub(Time).now {@now}
  end
  now
end
