require 'spec_helper'

describe Vidibus::Recording do
  let(:this) { Vidibus::Recording }

  def stub_loop(sleep = false)
    if sleep == false
      stub(this).sleep
    end
    stub(this).loop do |block|
      block.call
    end
  end

  describe '.monitor' do
    let(:recording) do
      Recording.create({
        :name => 'N-TV Live',
        :stream => 'rtmp://fms.rtl.de/ntvlive/livestream/channel1'
      })
    end

    it 'should call #autoload' do
      stub(this).run
      mock(this).autoload { [] }
      this.monitor
    end

    it 'should not run without recording classes' do
      dont_allow(this).run
      this.monitor
    end

    context 'with recording classes available' do
      before do
        this.autoload_paths = ['app/models/*.rb']
      end

      it 'should call #run' do
        mock(this).run
        this.monitor
      end

      it 'should loop endlessly' do
        mock(this).loop
        this.monitor
      end

      it 'should sleep after each iteration' do
        stub_loop(true)
        mock(this).sleep(Vidibus::Recording.monitoring_interval)
        this.monitor
      end

      it 'should do nothing without started recordings' do
        stub_loop
        dont_allow.any_instance_of(Recording).resume
        this.monitor
      end

      context 'with started recordings' do
        before do
          stub(recording).start_worker
          recording.start
        end

        it 'should log exceptions' do
          stub_loop
          stub.any_instance_of(Recording).worker_running? do
            raise 'That went wrong'
          end
          mock(this.logger).error.with_any_args
          expect { this.monitor }.not_to raise_error
        end

        context 'with a running worker' do
          before do
            stub.any_instance_of(Recording).worker_running? { true }
          end

          it 'should track progress' do
            stub_loop
            mock.any_instance_of(Recording).track_progress
            this.monitor
          end

          it 'should not resume' do
            stub_loop
            dont_allow.any_instance_of(Recording).resume
            this.monitor
          end
        end

        context 'without a running worker' do
          before do
            stub.any_instance_of(Recording).worker_running? { false }
          end

          it 'should resume' do
            stub_loop
            mock.any_instance_of(Recording).resume
            this.monitor
          end
        end
      end
    end
  end

  describe '.autoload' do
    it 'should do nothing unless autoload paths have been defined' do
      this.autoload_paths = []
      dont_allow(Dir)[]
      this.autoload
    end

    it 'should return all recording classes in autoload paths' do
      this.autoload_paths = ['app/models/*.rb']
      this.autoload.should eq([Recording])
    end

    it 'should set classes variable' do
      this.autoload_paths = ['app/models/*.rb']
      this.autoload
      this.classes.should eq([Recording])
    end
  end
end
