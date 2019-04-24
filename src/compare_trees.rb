#=============================================================================
# File: compare_trees.rb
# Description: Compare two directory trees and, optionally delete files in
#              source tree if it's anywere in the destination tree.
# Author: Praful https://github.com/Praful/compare-trees
# Licence: GPL v3
# Requires:
# - Linux diff program (or Windows version)
# 
# 
#=============================================================================
# History
#
# Compare two dirs recursively. If a file in first tree exists in the second tree, optionally
# delete the first file. To be regarded the same, the file names and contents must be the
# same.
#
# Definitions:
#   filepath is the full path of a file including the dir eg c:\temp\settings.ini
#   filename is just the file name excluding dir eg settings.ini
#   filecontents are what's inside the file; the file is considered binary.
#   source/src is the file provided by the user of class DirTree.
#   Destination/dst is the file in the tree encapsulated by class DirTree.
#
# v1    20110708
# v1.1  20110709
#   - Once files are deleted from dir, delete dir if it's empty.
# v1.2  20110709
#   - Standardize paths to be forward instead of back slashees since some
#     methods require them.
# v1.3  20110710
#   - Add filter feature to exclude source dir from dest dir tree. I was going
#     to add a /filter switch but have decided to always exclude source dir
#     from dest dir tree scan. If source dir is included in dest dir tree and a file
#     appears more than once in the source dir tree, the file deleted is unpredictable.
#     Also if source dir is included in dest dir tree, there will be attempts to delete
#     all copies of a file eg say source dir is c:\temp\a and dest dir is c:\temp and
#     identical files test.txt exists in c:\temp\a and c:\temp\a\b; when source file is
#     c:\temp\a\test.txt, dest dir will match with c:\temp\a\b\test.txt, which will result in
#     c:\temp\a\test.txt being deleted; then when source file is c:\temp\a\b\test.txt,
#     dest dir will match with c:\temp\a\test.txt in its tree (since tree is pre=built
#     using build_tree); there will be an attempt to compare the two files but
#     obviously this will fail since c:\temp\a\test.txt has already been deleted.
#     There will be an error message and c:\temp\a\b\test.txt won't be deleted but it
#     doesn't look good. There may be a better way of handling this but for now just
#     exclude source dir from dest dir tree scan.
#   - Show total number of bytes deleted (or would be deleted).
# v1.4  20111016
#   - Add exception handling in compare function.
# v1.5  20170123
#   - Match files by size (previously by name but no good if file names differ)

require 'find'

DEL_SWITCH = "/delete"

class DirTree

  # Use the *nix diff command, which is also available for Windows (download required).
  COMPARE_CMD = 'diff --binary --brief "%s" "%s"'
  # COMPARE_CMD_BC =  '"c:/program files/beyond compare 4/bcomp" /qc /silent "%s" "%s"'

  def initialize(dirpath, filter)
    @dirpath = dirpath
    @filter = filter
    puts "Scanning #{dirpath}..."
    build_tree
    puts "Scan finished"
  end

  # Build tree map where key is just filename and value is map of full paths
  # (including filename) of the file. The value is a map since a file of the
  # same name may exist in multiple dirs.
  def build_tree
    @tree_name = Hash.new
    @tree_size = Hash.new

    Find.find(@dirpath) do |path|
      next if !include_file?(path)

      filename = File.basename(path)
      filepath_map_name = @tree_name[filename] || Hash.new
      # filepath_map_name = Hash.new if filepath_map_name.nil?
      filepath_map_name[path] = nil
      @tree_name[filename] = filepath_map_name

      size = File.size(path)
      filepath_map_size = @tree_size[size] || Hash.new
      # filepath_map_size = Hash.new if filepath_map_size.nil?
      filepath_map_size[path] = nil
      @tree_size[size] = filepath_map_size
    end
  end

  # Return true if file should be included in our tree.
  def include_file?(path)
    return false if !File.file?(path)
    return true if @filter.nil?
    return !path.start_with?(@filter)
  end

  # Return true if filepath exists in our folder tree.
  # To exist in our tree, the contents of filepath and the file in our tree must be the same.
  def contains?(src_filepath)
    return !filepath(src_filepath).nil?
  end

  # Match by file name.
  # Return filepath of file in our tree that matches src_filepath.
  # Return nil if no matching file found (which means match doesn't exist or files differed).
  def filepath_by_name(src_filepath)
    src_filename = File.basename(src_filepath)
    filepath_map_name = @tree_name[src_filename]
    return nil if filepath_map_name.nil?

    filepath_map_name.each_key do |dst_filepath|
      return dst_filepath if files_same?(src_filepath, dst_filepath)
    end
    return nil
  end

  # For backward compatibilty
  alias_method :filepath, :filepath_by_name

  # Match by file size.
  # Return filepath of file in our tree that matches src_filepath.
  # Return nil if no matching file found (which means match doesn't exist or files differed).
  def filepath_by_size(src_filepath)
    size = File.size(src_filepath)
    filepath_map_size = @tree_size[size]
    return nil if filepath_map_size.nil?

    filepath_map_size.each_key do |dst_filepath|
      return dst_filepath if files_same?(src_filepath, dst_filepath)
    end
    return nil
  end

  # Match by file size.
  # Return filepath of file in our tree that matches src_filepath.
  # Return nil if no matching file found (which means match doesn't exist or files differed).
  # def filepath_by_size_image(src_filepath)
    # image_size = File.size(src_filepath)

    # ((image_size-10)..(image_size+10)).each do |size|
      # filepath_map_size = @tree_size[size]
      # next if filepath_map_size.nil?
      # puts "#{size} = #{filepath_map_size.count}"
      # filepath_map_size.each_key do |dst_filepath|
        # return dst_filepath if image_same?(src_filepath, dst_filepath)
      # end
    # end
    # return nil
  # end

  # Return true if contents of the two files are identical.
  def files_same?(filepath1, filepath2)
    begin
      return false if filepaths_same?(filepath1, filepath2) # ignore when source and dest filepaths are the same.
      return false if !filesizes_same?(filepath1, filepath2) # if sizes are different then contents are different.
      return filecontents_same?(filepath1, filepath2)
    rescue => ex
      puts "Error comparing #{filepath1} and #{filepath2}: #{ex.class} - #{ex.message}"
      return false
    end
  end

  # Return true if filepaths are the same ie they refer to same file (ignore case of filepaths).
  def filepaths_same?(filepath1, filepath2)
    return 0 == filepath1.casecmp(filepath2)
  end

  # Return true if file contents are the same.
  def filecontents_same?(filepath1, filepath2)
    return system(COMPARE_CMD % [filepath1, filepath2])
  end

  # def image_same?(filepath1, filepath2)
    # return false if filepaths_same?(filepath1, filepath2) # ignore when source and dest filepaths are the same.
    # system(COMPARE_CMD_BC % [filepath1, filepath2])
    # return true if ($?.exitstatus == 1) || ($?.exitstatus == 2)
  # end

  # Return true if file sizes are the same
  def filesizes_same?(filepath1, filepath2)
    return File.size(filepath1) == File.size(filepath2)
  end
end

# =============================================================================
# Add methods to let us know whether there are any files in a dir.
class Dir
 def empty?
   # Ruby in Windows doesn't like backslashes in path for Dir.glob function.
   dir = standardize_path(path)

   Dir.glob("#{dir}/*", File::FNM_DOTMATCH) do |e|
     return false unless %w( . .. ).include?(File::basename(e))
   end
   return true
 end
 def self.empty? path
   new(path).empty?
 end
end
# =============================================================================
#
# From http://www.ruby-forum.com/topic/119703
# If Rails is installed, similar functionality is found in
# http://api.rubyonrails.org/classes/ActionView/Helpers/NumberHelper.html#M000524
K = 2.0**10
M = 2.0**20
G = 2.0**30
T = 2.0**40
def nice_bytes( bytes, max_digits=3 )
  value, suffix, precision = case bytes
    when 0...K
      [ bytes, 'b', 0 ]
    else
      value, suffix = case bytes
        when K...M then [ bytes / K, 'KB' ]
        when M...G then [ bytes / M, 'MB' ]
        when G...T then [ bytes / G, 'GB' ]
        else            [ bytes / T, 'TB' ]
      end
      used_digits = case value
        when   0...10   then 1
        when  10...100  then 2
        when 100...1000 then 3
      end
      leftover_digits = max_digits - used_digits
      [ value, suffix, leftover_digits > 0 ? leftover_digits : 0 ]
  end
  "%.#{precision}f#{suffix}" % value
end

# For all files in source_dir tree, check if file exists anywhere in dest_dir. Delete source_dir file
# if do_delete is true.
def compare(source_dir, dest_dir, do_delete=false, do_filter=false)
  source_dir = standardize_path(source_dir)
  dest_dir = standardize_path(dest_dir)
  filter = do_filter ? source_dir : nil

  puts "Comparing #{source_dir} with #{dest_dir}. Delete files: #{do_delete}."
  dest_tree = DirTree.new(dest_dir, filter)
  total_file_count = 0
  del_count = 0
  byte_count = 0

  Find.find(source_dir) do |src_filepath|
    next if !File.file?(src_filepath)

    total_file_count += 1
    begin
      # dest_filepath = dest_tree.filepath_by_name(src_filepath)
      dest_filepath = dest_tree.filepath_by_size(src_filepath)
      # dest_filepath = dest_tree.filepath_by_size(src_filepath)
      if !dest_filepath.nil? then
        size = File.size(src_filepath)
        size2 = File.size(dest_filepath)
        if do_delete then
          begin
            path = src_filepath
            File.delete(src_filepath)
            puts "Deleted #{src_filepath}  =  #{dest_filepath}"
            del_count += 1
            byte_count += size
            path = File.dirname(src_filepath)
            if Dir.empty?(path) then
              Dir.rmdir(path)
              puts "Deleted empty directory #{path}"
            end
          rescue => ex
            puts "Error deleting #{path}: #{ex.class} - #{ex.message}"
          end
        else
          puts "Would be deleted #{src_filepath} (#{size}) =  #{dest_filepath} (#{size2}"
          del_count += 1
          byte_count += size
        end
      else
        puts "No match: #{src_filepath}"
      end
    rescue => ex
      puts "Error processing file #{src_filepath}: #{ex.class} - #{ex.message}"
    end
  end
  puts "#{del_count} of #{total_file_count} files deleted. Total size: #{nice_bytes(byte_count)}.\r"
end

# Use forward slashes in path otherwise, on Windows, Ruby ends up with a mixture of
# forward and back slashes in paths. Some Ruby methods require forward slashes always
# eg File.dirname.
def standardize_path(path)
  return path.gsub(/\\/, "\/")
end

#TODO use main command line gem
#TODO add /size switch to compare by file size not file name.

def usage
  puts "\n  Usage:  ruby compare_trees.rb <source directory> <dest directory> [/delete]"
  puts "\nIf /delete is provided, files in source directory are deleted if \nthey exist somewhere in the dest dir tree."
  puts "\nIf files are deleted from a directory, the directory is deleted if it's empty."
  puts "\nBoth directories are recursed and you are NOT asked to confirm file deletion."
  puts "\nUSE AT OWN RISK!"
end

def args_OK
  if ARGV.length < 2 || ARGV.length > 3 then
    puts "Error: incorrect number of parameters."
    return false
  end
  if !File.directory?(ARGV[0]) then
    puts "Error: source directory #{ARGV[0]} does not exist."
    return false
  end
  if !File.directory?(ARGV[1]) then
    puts "Error: destination directory #{ARGV[1]} does not exist."
    return false
  end
  if (ARGV.length == 3) && (ARGV[2].casecmp(DEL_SWITCH) != 0) then
    puts "Error: final parameter must be blank or /delete."
    return false
  end
  return true
end
# =============================================================================

if !args_OK then
  usage
  exit
end

do_delete = (ARGV.length == 3) && (ARGV[2].casecmp(DEL_SWITCH) == 0)

compare ARGV[0], ARGV[1], do_delete, true

#compare "C:/temp", "C:/temp"
#puts system "diff --binary -q \"C:/temp/wget.exe\" \"C:/apps/PK/wget.exe\""


