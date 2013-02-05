module AbfWorker
  class BaseObserver
    COMPLETED = 0
    FAILED    = 1
    PENDING   = 2
    STARTED   = 3
    CANCELED  = 4

    attr_accessor :status, :options

    protected

    def initialize(options, subject_class)
      @status   = options['status'].to_i
      @options  = options
      @subject_class = subject_class
    end

    def subject
      @subject ||= @subject_class.find options['id']
    end

    def perform
      raise NotImplementedError, "You should implement this method"
    end

    def update_results
      results = (subject.results || []) + options['results']
      sort_results_and_save results
    end

    def sort_results_and_save(results, item = nil)
      item ||= subject
      item.results = results.sort_by{ |r| r['file_name'] }
      item.save!
    end

  end
end