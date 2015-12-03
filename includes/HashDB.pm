##################################################################################
# Author      : Vijay Karingula
# Name        : HASHDB.pm
# Date        : December 1 2015
# Description : This file is a package that consists of sub routines definitions
#               to create BerkeleyDB file and Delete BerkeleyDB file   
##################################################################################

package HashDB;

use BerkeleyDB;

sub create_berkeleyDB {
  my ($input_dir) = @_;
  my $filename = <$input_dir/data.db>;
  my $dbh = new BerkeleyDB::Hash(
        -Filename =>$filename,
        -Flags    =>DB_CREATE)
        or die "Error opening $filename: $! $BerkeleyDB::Error\n";
  return $dbh;
}

sub delete_berkeleyDB {
  my ($input_dir) = @_;
  my $filename = <$input_dir/data.db>;
  my $remove_status = BerkeleyDB::db_remove(
                  -Filename=>$filename);
  if (remove_status) {
    print "Old berkeleydb file is deleted\n";
  }
  
}

1;