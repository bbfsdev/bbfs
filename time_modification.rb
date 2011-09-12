class TimeModification
  # Unify modification/first_appearance time according to input DB
  # TODO Move to FileUtils
  # Input: ContentData
  # Output: ContentData with unified times
  #         Files modification time attribute physically updated
  # Assumption: Files in the input db are from this device. 
  #             There is no check what device they are belong - only the check of server name.
  #             It is a user responsibility (meanwhile) to provide a correct input
  #             If file has a modification time attribute that doesn't present in the input db,
  #             then the assumption is that this file wasnt indexized and it will not be treated
  #             (e.i. we do nothing with it)
  def self.modify(db)
    mod_db = ContentData.unify_time (db)
    unify_time(db, mod_db)
    mod_db
  end
  
  
  def self.unify_time(db, mod_db)
    mod_db.instances.each_value do |instance| 
      next unless db.instances.has_key?instance.global_path
      if (File.exists?(instance.full_path) \
        and File.mtime(instance.full_path) == db.instances[instance.global_path].modification_time \
        and File.size(instance.full_path) == instance.size \
        and `hostname`.chomp == instance.server_name \
        and (File.mtime(instance.full_path) <=> instance.modification_time) > 0) 
          File.utime(File.atime(instance.full_path), instance.modification_time, instance.full_path)                        
      end              
    end
  end
end