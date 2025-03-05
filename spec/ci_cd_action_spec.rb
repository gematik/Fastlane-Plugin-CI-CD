describe Fastlane::Actions::CiCdAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The ci_cd plugin is working!")

      Fastlane::Actions::CiCdAction.run(nil)
    end
  end
end
