namespace :encryption do
  desc "Encrypt all existing unencrypted records"
  task migrate: :environment do
    models = [User, JournalEntry, JobPage, Session]

    models.each do |model|
      count = 0
      puts "Encrypting #{model.name}..."

      model.find_each do |record|
        record.save!
        count += 1
        print "." if (count % 100).zero?
      end

      puts "\n  Done: #{count} records"
    end

    puts "\nEncryption migration complete!"
    puts "You can now remove `support_unencrypted_data` from production.rb"
  end
end
