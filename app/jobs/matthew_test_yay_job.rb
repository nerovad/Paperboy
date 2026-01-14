class MatthewTestYayJob
  include Sidekiq::Job

  def perform(params)
    MatthewTestYay::MatthewTestYayService
      .new(params.symbolize_keys)
      .call
  end
end
