# ------------------------------------------------------------ #
# PG_Database.pm
# Perl module for accessing tables in Postgres Database
#
# Author: Taein Lee
#         Adapted for generalized trait loaders by Ethy Cannon
#
# ------------------------------------------------------------ #
#
# CLASS METHODS
#
# [Dababase Conncetivities]
#  connect_db()               : connect to database
#  disconnect_db()            : disconnect from database
#
# [Database Information]
#  get_db_name()              : return the name of database
#
# [SQL Statements]
#  execute_query_stmt(stmt)   : execute SQL statement
#  query_stmt(stmt)           : execute SQL statement and return statement handler
#  query_field(stmt)          : return the first value of the column of the returned record
#  query_fields(stmt)         : return the first row of the returned record
#  get_data_ref(stmt)         : return reference of 2D array
#  get_ranged_data_ref(stmt, order_by, base, offset)    : return total number of rows, number of rows, number of columns and reference of 2D array
#  insert_new_record($table_name, $data_ref, <$column>) : insert a record to database
#  update_record($table_name, $data_ref, $pr_field, $pr_value)  : update the record in database
#  get_num_records(data_ref)  : return number of records in data_ref
#
# [Data Extractions]
#  execute_sql_to_excel($stmt, <$outfile>)   : execute SQL statement and store the result to an Excel sheet
#  execute_sql_to_text($stmt, <$outfile>)    : execute SQL statement and store the result to a text file
#  execute_sql_file_to_excel($infile, <$outfile> : execute SQL statements and store the results to an Excel sheet
#  execute_sql_file_to_text($stmt, <$outfile>)   : execute SQL statement and store the result to text files
#  extract_tables_to_excel($table_name_ref, <$outfile>) : extract and store the contents of a table to an Excel sheet
#  extract_tables_to_text($table_name_ref, <$outfile>)  : extract and store the contents of a table to a text file
#
# [Table Information]
#  str_all_tables_names()      : return all names of tables
#  does_table_exist(table_name, <table_type>)  : returns true if the table exists in database
#  get_table_info(table_name)  : return the number of fields and hash{ field name => data type}
#  str_table_info(table_name)  : return the information of the specified table
#  get_column_names(table_name): return column names of a table
#
# [Primitive subroutines]
#  trim(string)          : remove white spaces at front and end
#  quote(string)         : preserve quotation marks
#  unquote(string)       : subsititute '' to '
#  slim(string)          : remove consecutive white spaces
#  trim_slim             : trim + slim
#  trim_quote            : trim + quote
#  trim_unquote          : trim + unquote
#  trim_slim_quote       : trim + slim + quote
#  trim_capitalize_first : trim and capitalize the first letter of a word
#  print_error_msg       : prints error messages onto the browser
# ------------------------------------------------------- #

package PG_Database;
use strict;
use DBI;
use Encode;
use Cwd;
use Data::Dumper;

  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #               CLASS DATA MEMBERS                    #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  my $dbh;
  my $loghandle;
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #               CLASS CONSTANCES                      #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#  
  #-----------------------------------------------------#
  # constructor
  #-----------------------------------------------------#
  sub new {
    my ($class, $config)= @_;
    
    my $self= bless {
      _connect_str => $config->{'db_connect_str'},
      _username    => $config->{'db_user'},
      _password    => $config->{'db_pass'},
    }, $class;
    
    # Open a file for logging SQL statements.
    open $loghandle, '>', $config->{'log_folder_sub'} . '/stmts.sql';
    
    return $self;
  }
  
  
  #-----------------------------------------------------#
  # destructor
  #-----------------------------------------------------#
  sub DESTROY {
    close $loghandle;
    undef;
  }
  
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #                 PRIVATE METHODS                     #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #                 PUBLIC METHODS                      #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #              Dababase Connections                   #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #-----------------------------------------------------#
  # connect to database : returns database handle
  #-----------------------------------------------------#
  sub connect_db {
    my $self= shift;
    
    # connnect to database
    $dbh = DBI->connect("$self->{_connect_str}", 
                        $self->{_username}, $self->{_password}, 
                        { PrintError => 1, RaiseError => 1 })
          or die "Error: Can't connect to the database $DBI::errstr \n";
    return $dbh;
  }
  
  
  #-----------------------------------------------------#
  # disconnect
  #-----------------------------------------------------#
  sub disconnect_db {
    # disconnect from database
    $dbh->disconnect() or warn "Error: disconnection failed: $DBI::errstr\n";
  }
  
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #                 Database Information                #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  
  #-----------------------------------------------------#
  # get_db_name: returns name of database
  #-----------------------------------------------------#
  sub get_db_name {
    my $self= shift;
    return $self->{_dbname};
  }
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #                  SQL Statements                     #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #-----------------------------------------------------#
  # execute sql statment                                #
  #-----------------------------------------------------#
  sub execute_query_stmt {
    my ($self, $stmt)= @_;
    
    # record statement
    $self->write_log($stmt);
    
    # encode SQL statement in UTF-8
    $stmt = encode("utf8", $stmt);
    
    # execute sql statement
    my $sth= $dbh->prepare($stmt) or die "Can't prepare the query $DBI::errstr\n";
    $sth->execute() or die "Can't execute $DBI::errstr\n";
    $sth->finish();
  }
  
  #-----------------------------------------------------#
  # send query statement and return statment handler
  #-----------------------------------------------------#
  sub query_stmt {
    my ($self, $stmt)= @_;
    
    # record statement
    $self->write_log($stmt);

    # encode SQL statement in UTF-8
    $stmt = encode("utf8", $stmt);
    
    # send sql statement and return statment handler
    my $sth= $dbh->prepare($stmt) or die "Can't prepare the query $DBI::errstr\n";
    $sth->execute() or die "Can't execute $DBI::errstr\n";
    return $sth;
  }
  
  #-----------------------------------------------------------#
  # insert_new_record                                         #
  #  return id that has just created if columnn is specified #
  #  (can be replaced by DBI::last_insert_id()               #
  #-----------------------------------------------------------#
  sub insert_new_record {
    my ($self, $table_name, $data_ref, $column)= @_;
    
    # create sql statement for insertion
    my $stmt= "INSERT INTO $table_name (";
    my @list= keys (%$data_ref);
    $stmt.= join(",", @list).") values (";
    @list= values(%$data_ref);
    @list= map { "'".$_."'" } @list;
    $stmt.= join(",", @list).")";
    
    # execute sql statement
    $self->execute_query_stmt($stmt);
    print "\tDBI: inserted a new record into $table_name\n";
    
    # return last inserted id
    if (defined $column) {
      return $self->query_field("SELECT MAX($column) FROM $table_name");
    }
  }
  
  #-----------------------------------------------------------#
  # update_record                                             #
  #-----------------------------------------------------------#
  sub update_record {
    my ($self, $table_name, $data_ref, $pr_field, $pr_value)= @_;
    
    # create SQL statement for update
    my $stmt= "UPDATE $table_name SET ";
    my @set= ();
    foreach my $key (keys (%$data_ref)) {
      push @set, qq{ $key = '$data_ref->{$key}' };
    }
    $stmt.= join(", ",@set)." where $pr_field = '$pr_value' ";
    
    # encode SQL statement in UTF-8
    $stmt = encode("utf8", $stmt);
    
    # execute SQL statement
    my $sth= $dbh->prepare($stmt) or die "Can't prepare the query $DBI::errstr\n";
    $sth->execute() or die "Can't execute $DBI::errstr\n";
    $sth->finish();
    print "\tDBI: updated the record in $table_name\n";
  }
  
  
  #-----------------------------------------------------------#
  # get_num_records                                           #
  #-----------------------------------------------------------#
  sub get_num_records {
    my ($self, $data_ref)= @_;
    return scalar @$data_ref;
  }
  
  #-----------------------------------------------------#
  # send query statement and return a value of the field
  #-----------------------------------------------------#
  sub query_field {
    my ($self, $stmt)= @_;
    
    # send query statement
    my $sth= $self->query_stmt($stmt);
    my @row= $sth->fetchrow_array();
    $sth->finish();
    
    # return empty string if no data found in table
    return ((scalar @row) == 0 || not defined($row[0])) ? "" : $row[0];
  }
  
  #-----------------------------------------------------#
  # send query statement and return values of the fields
  #-----------------------------------------------------#
  sub query_fields {
    my ($self, $stmt)= @_;
    
    # send query statement
    my $sth= $self->query_stmt($stmt);
    my @row= $sth->fetchrow_array();
    $sth->finish();
    return \@row;
  }
  
  #-----------------------------------------------------#
  # get reference data (2D array) 
  #  return reference of 2D array
  #-----------------------------------------------------#
  sub get_data_ref {
    my ($self, $stmt)= @_;
    
    # encode SQL statement in UTF-8
    $stmt = encode("utf8", $stmt);
    
    # prepare and send SQL statemet to the database
    my $sth= $dbh->prepare($stmt) or die "Can't prepare the query $DBI::errstr\n";
    $sth->execute() or die "Can't execute $DBI::errstr\n";
    
    # retrieve data from database
    my $data_ref= [];
        while (my @row= $sth->fetchrow_array()) {
      push(@$data_ref,[@row]);
    }
      $sth->finish();        
        return $data_ref;
  }
  
  #-----------------------------------------------------#
  # get reference data (2D array) 
  #  return total number of rows, number of rows,
  #  number of columns and reference of 2D array
  #-----------------------------------------------------#
  sub get_ranged_data_ref {
    my ($self, $stmt, $order_by, $base, $offset)= @_;
    my ($num_rows_total, $num_rows, $num_cols);
    
    # count number of column
    $stmt =~ /SELECT (.*) FROM/;
    my @list      = split(/[;,]/, $1);
    $num_cols      = scalar @list;
    
    # add order by clause
    $stmt.= $order_by;
    
    # encode SQL statement in UTF-8
    $stmt = encode("utf8", $stmt);
    
    # prepare and send SQL statemet to the database
    my $sth= $dbh->prepare($stmt) or die "Can't prepare the query $DBI::errstr\n";
    $sth->execute() or die "Can't execute $DBI::errstr\n";
    
    # retrieve data from database
    my $data_ref= [];
    my $end_row= $base + $offset;
      $num_rows= $num_rows_total= 0;
      while (my @row= $sth->fetchrow_array()) {
       if ($num_rows_total >= $base && $num_rows_total < $end_row) {
        push(@$data_ref,[@row]);
       ++$num_rows;
    }
      ++$num_rows_total;
    }
    $sth->finish();
      
    #-------------------------------------------------#
    # create a new SQL statement
    #$stmt =~ /SELECT (.*) FROM (.*) WHERE/;
    #my $select_lst  = $1;
    #my $from_lst  = $2;
    #my @list    = split(/[;,]/, $select_lst);
    #my $num_cols  = scalar @list;
    #my $offset= $base + $count;
    #$new_stmt= "SELECT $select_lst FROM (SELECT ROW_NUMBER() OVER (ORDER BY $order_by) LINES, ".
    #       "$select_lst FROM $from_lst) WHERE LINES BETWEEN $base AND $offset";
    #-------------------------------------------------#
        return ($data_ref, $num_rows_total, $num_rows, $num_cols, $stmt);
  }
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #                 Data Extractions                    #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #-----------------------------------------------------#
  # execute_sql_to_excel
  #-----------------------------------------------------#
  sub execute_sql_to_excel {
    my ($self, $stmt, $outfile)= @_;
    
    # get file name
    $outfile= (defined $outfile) ? $outfile : "extracted_table.xls";
    
    # open an Excel file for writting
    my $workbook= Spreadsheet::WriteExcel::Big->new($outfile);
    
    # add a new worksheet
    my $worksheet= $workbook->addworksheet();
    
       # extract data from table
       my $sth= $self->query_stmt($stmt);
    
    # write out headers
    $stmt=~ /^select (.*) from/i;
    my @headers= split(/[;,]/, $1);
    @headers= map { $self->trim($_) } @headers;
    for (my $i= 0; $i < scalar @headers; $i++) {
      $worksheet->write(0,$i,"$headers[$i]");
    }
    
    # write out contents
    my $counter= 1;
    while (my @row= $sth->fetchrow_array()) {
      for (my $i= 0; $i < scalar @row; $i++) {
        my $value= (defined $row[$i]) ? $row[$i] : "";
        $worksheet->write($counter,$i,"$value");
      }
      ++$counter;
    }
    $sth->finish();
    $workbook->close();
  }
  
  #-----------------------------------------------------#
  # execute_sql_to_text
  #-----------------------------------------------------#
  sub execute_sql_to_text {
    my ($self, $stmt, $outfile)= @_;
    
    # get file name
    $outfile= (defined $outfile) ? $outfile : "sql_extracted_data.txt";
    (open FDW, ">$outfile") or die "ERROR: cannot open file $outfile for writing\n";
    
    # extract data from table
       my $sth= $self->query_stmt($stmt);
    
    # write out headers
    $stmt=~ /^select (.*) from/i;
    my @headers= split(/[;,]/, $1);
    @headers= map { $self->trim($_) } @headers;
    print FDW join("\t", @headers), "\n";
    
    # write out contents
    while (my @row= $sth->fetchrow_array()) {
      print FDW join("\t", @row), "\n";
    }
    $sth->finish();
    close(FDW);
  }
  
  #-----------------------------------------------------#
  # execute_sql_file_to_excel
  #-----------------------------------------------------#
  sub execute_sql_file_to_excel {
    my ($self, $infile, $outfile)= @_;
    
    # get file name
    $outfile= (defined $outfile) ? $outfile : "extracted_table.xls";
    
    # open an Excel file for writting
    my $workbook= Spreadsheet::WriteExcel::Big->new($outfile);
    
    # open input file
    (open FDR, "<$infile")  or die "ERROR: cannot open file $infile for reading\n";
    my $num_sql= 1;
    while (<FDR>) {
      /^\s+/ and next;
      
      # create a new worksheet
      my $worksheet= $workbook->addworksheet($num_sql);
      
      # extract data from table
      my $stmt= $self->trim($_);
      my $sth= $self->query_stmt($stmt);
      
      # write out headers
      $stmt=~ /^select (.*) from/i;
      my @headers= split(/[;,]/, $1);
      @headers= map { $self->trim($_) } @headers;
      for (my $i= 0; $i < scalar @headers; $i++) {
        $worksheet->write(0,$i,$headers[$i]);
      }
      
      # write out contents
      my $counter= 1;
      while (my @row= $sth->fetchrow_array()) {
        for (my $i= 0; $i < @row; $i++) {
          my $value= (defined $row[$i]) ? $row[$i] : "";
          $worksheet->write($counter,$i,"$value");
        }
        ++$counter;
      }
      ++$num_sql;
    }
    close(FDR);
       $workbook->close();
  }
  
  #-----------------------------------------------------#
  # execute_sql_file_to_text
  #-----------------------------------------------------#
  sub execute_sql_file_to_text {
    my ($self, $infile, $outfile)= @_;
    
    # open input file
    (open FDR, "<$infile")  or die "ERROR: cannot open file $infile for reading\n";
    my $counter= 1;
    while (<FDR>) {
      /^\s+/ and next;
      
      # open a file for output
      $outfile= (defined $outfile) ? $outfile.'_' : '';
      $outfile= sprintf ("%s%d",$counter);
      (open FDW, ">$outfile") or die "ERROR: cannot open file $outfile for writing\n";
      
      # write result
      execute_sql_to_text($self->trim($_),$outfile);
      
      close(FDW);
      ++$counter;
    }
  }
  
  #-----------------------------------------------------#
  # extract_tables_to_excel
  #-----------------------------------------------------#
  sub extract_tables_to_excel {
    my ($self, $table_name_ref, $outfile)= @_;
    my ($stmt, $sth);
    
    # get file name
    $outfile= (defined $outfile) ? $outfile : "extracted_tables.xls";
    
    # open an Excel file for writting
    my $workbook= Spreadsheet::WriteExcel::Big->new($outfile);
    
    for my $table_name (@$table_name_ref) {
      # check if the table exists
      ($self->does_table_exist($table_name)) or die "\tError: $table_name does not exist\n";
      
      # add a new worksheet
      my $worksheet= $workbook->addworksheet($table_name);
      
      # extract field names
      my $fields_ref= $self->get_column_names($table_name);
      my $select_str= join(",",@$fields_ref);
      
      # extract data from table
      $sth= $self->query_stmt("SELECT $select_str FROM $table_name ORDER BY $fields_ref->[0]");
      
      # write out header
      my $format= $workbook->add_format();
      $format->set_bold();
      for (my $i= 0; $i < @$fields_ref; $i++) {
        $worksheet->write(0,$i,$fields_ref->[$i],$format);
      }
      
      # write out contents
      my $counter= 1;
      while (my @row= $sth->fetchrow_array()) {
        for (my $i= 0; $i < @row; $i++) {
          my $value= (defined $row[$i]) ? $row[$i] : "";
          $worksheet->write($counter, $i, "$value");
        }
        ++$counter;
      }
      $sth->finish();
    }
    $workbook->close();
  }
  
  #-----------------------------------------------------#
  # extract_tables_to_text
  #-----------------------------------------------------#
  sub extract_tables_to_text {
    my ($self, $table_name_ref, $outfile)= @_;
    my ($stmt, $sth);
    
    # get file name
    $outfile= 'extracted_tables' if (!defined $outfile);;
    
    for my $table_name (@$table_name_ref) {
      # check if the table exists
      ($self->does_table_exist($table_name)) or die "\tError: $table_name does not exist\n";
      
      # open a text file for writting
      my $outfile= $outfile.'_'.$table_name.'.txt';
      (open FDW, ">$outfile") or die "ERROR: cannot open file $outfile for writing\n";
      
      # extract field names
      my $fields_ref= $self->get_column_names($table_name);
      my $select_str= join(",",@$fields_ref);
      
      # extract data from table
      $sth= $self->query_stmt("SELECT $select_str FROM $table_name ORDER BY $fields_ref->[0]");
      
      # write out header
      print FDW join("\t", @$fields_ref), "\n";
      
      # write out contents
      my $counter= 1;
      while (my @row= $sth->fetchrow_array()) {
        print FDW join("\t", @row), "\n";
      }
      $sth->finish();
      close(FDW);
    }
  }
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #                 Table Information                   #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #-----------------------------------------------------#
  # str_all_tables_names                                #
  #-----------------------------------------------------#
  sub str_all_tables_names {
    my ($self)= @_;
    my $string= "";
    
    my @tables= $dbh->tables();
    $string.= "\t============================================\n";
    $string.= "\n\tTable Names\n";
    $string.= "\t============================================\n";
    foreach my $table (@tables) {
      $string.= "table: $table\n";
    }
    return $string;
  }
  
  #-----------------------------------------------------#
  # does_table_exist
  #-----------------------------------------------------#
  sub does_table_exist {
    my ($self, $table_name, $table_type)= @_;
    
    # get owner name and table name
    my ($owner, $table, $obj_type) = ("","","");
    if (index($table_name, '.') > 0) {
      ($owner, $table) = ($table_name =~ /(\w+)\.([\w\$]+)/);
    }
    else { $table= $table_name; }
    
    # check the existence of the table in database
    $table_type= 'TABLE' if ! $table_type;
    $obj_type= ($owner) ? 'all_objects' : 'user_objects';
    my $stmt= "select object_name from $obj_type where object_name = '";
    $stmt.= uc($table)."' ";
    $stmt.= " AND owner = '".uc($owner)."'" if ($owner);
    my $result= $self->query_field($stmt);
    return ($result eq "") ? 0 : 1;
  }
  
  #-----------------------------------------------------#
  # get_table_info (single table)
  # return information of a table
  #   - number of fields
  #   - hash (field name => data type)
  #-----------------------------------------------------#
  sub get_table_info {
    my ($self, $table_name)= @_;
    my %table_info= ();
    my $num= 0;
    
    #check if the table exists
    if ($self->does_table_exist($table_name)) {
      # get the table information
      my $sth= $self->query_stmt("SELECT * FROM $table_name");
      $num= $sth->{NUM_OF_FIELDS};
      for (my $i= 0; $i < $num; $i++) {
        $table_info{$sth->{NAME}->[$i]}= $sth->{TYPE}->[$i];
      }
      $sth->finish();
    }
    return ($num, \%table_info);
  }
  
  #-----------------------------------------------------#
  # str_table_info (single table)
  #-----------------------------------------------------#
  sub str_table_info {
    my ($self, $table_name)= @_;
    my $string= "";
    
    #check if the table exists
    if ($self->does_table_exist($table_name)) {
      
      # get table information
      my ($num, $table_ref)= $self->get_table_info($table_name);
      $string.= "\n\tTable information for $table_name\n\t====================================\n";
      $string.= "\tNumber of fields: $num\n\n";
      $string.= "\tColumn Name                 Type\n";
      $string.= "\t--------------------------- ----\n";
      foreach my $key (keys %$table_ref) {
        $string.= sprintf("\t%-26s  %4d\n", $key, $table_ref->{$key});
      }
      $string.= "\t====================================\n\n";
    }
    return $string;
  }
  
  #-----------------------------------------------------#
  # get_column_names
  #-----------------------------------------------------#
  sub get_column_names {
    my ($self, $table_name)= @_;
    my @fields= ();
    
    # check if the table exists
    $self->does_table_exist($dbh, $table_name);
    
    # get names of field
    my $sth= $self->query_stmt("SELECT * FROM $table_name");
    my $num= $sth->{NUM_OF_FIELDS};
    for (my $i= 0; $i < $num; $i++) {
      $fields[$i]= lc($sth->{NAME}->[$i]);
    }
    $sth->finish();
    return \@fields;
  }
  
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #               Primitive subroutines                 #
  #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
  #-----------------------------------------------------#
  # trim : remove white spaces at front and end
  #-----------------------------------------------------#
  sub trim {
    my ($self, $string)= @_;
    return q{} if (!defined $string);
    $string=~ s/^\s+//;
    $string=~ s/\s+$//;
    return $string;
  }
  
  #-----------------------------------------------------#
  # quote: preserve quotation marks
  #-----------------------------------------------------#
  sub quote {
    my ($self, $string)= @_;
    return q{} if (!defined $string);
    $string =~ s{\\}{\\\\}g;
    $string =~ s{\'}{\'\'}g;
    return $string;
  }
  
  #-----------------------------------------------------#
  # unquote: unqutoe
  #-----------------------------------------------------#
  sub unquote {
    my ($self, $string)= @_;
    return q{} if (!defined $string);
    $string =~ s{\'\'}{\'}g;
    return $string;
  }
  
  #-----------------------------------------------------#
  # slim: remove consecutive white spaces
  #-----------------------------------------------------#
  sub slim {
    my ($self, $string)= @_;
    return q{} if (!defined $string);
    $string =~ s/\s{2,}/ /g;
    return $string;
  }
  
  #-----------------------------------------------------#
  # trim_quote:
  #-----------------------------------------------------#
  sub trim_quote {
    my ($self, $string)= @_;
    return $self->trim($self->quote($string));
  }
  
  #-----------------------------------------------------#
  # trim_unquote: trim + unquote
  #-----------------------------------------------------#
  sub trim_unquote {
    my ($self, $string)= @_;
    return $self->trim($self->unquote($string));
  }
  
  #-----------------------------------------------------#
  # trim_slim : trim + slim
  #-----------------------------------------------------#
  sub trim_slim {
    my ($self, $string)= @_;
    return $self->trim($self->slim($string));
  }
  
  #-----------------------------------------------------#
  # trim_slim_quote : trim + slim + quote
  #-----------------------------------------------------#
  sub trim_slim_quote {
    my ($self, $string)= @_;
    return $self->trim($self->slim($self->quote($string)));
  }
  
  #-----------------------------------------------------#
  # trim_capitalize_first: trim + capitalize the first character of a word
  #-----------------------------------------------------#
  sub trim_capitalize_first {
    my ($self, $string)= @_;
    $string= lc($self->trim($string));
    $string =~ s/^(\w)/\u$1/;
    $string =~ s/\s(\w)/ \u$1/g;
    return $string;
  }
  
  #-----------------------------------------------------#
  # prints error messages onto the browser
  #-----------------------------------------------------#
  sub print_error_msg {
    my ($self, $title, $msg) = @_;
  # print html file
  #=====================================================#
print <<END_HTML; 
Content-type: text/html

<html>
  <head><title>$title</title></head>
  <body>
    <br><br>$msg<br><br>
  </body>
</html>

END_HTML
  #=====================================================#
  }
  
  
  #-----------------------------------------------------#
  # write text to log
  #-----------------------------------------------------#
  sub write_log {
    my ($self, $msg) = @_;
    print $loghandle "$msg\n\n";
  }
1;
__END__
