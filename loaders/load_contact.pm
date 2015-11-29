###############################################################################
# Author      : Ethy Cannon 
#               NOTE: developed from scripts written by Taein Lee, 
#                     Main Lab, Washington State University.
# Name        : load_contact.pm
# Date        : November, 2015
# Description : loader for 'contact' worksheet
###############################################################################

use strict;

our $name_code_ref;


#-----------------------------------------------------------------------------#
# process_contact
#-----------------------------------------------------------------------------#
sub process_contact {
  my ($pg_db, $oBook, $module_ref, $data_info_ref)= @_;
  my %record_new_table = ();

#TODO: may not want this; seems to only be used to count records inserted
  # pre-processing
#  my $num_record_ref= module_pre_process($module_ref->{MODULE});

  # process excel sheet
  my ($excel_ref, $cvterm_ref, $sp_col_refs, $error)
      = process_excel($oBook, $module_ref->{SHEET}, $data_info_ref);
  if ($error ne '') {
    println("\n$error\n\t[$module_ref->{SHEET}] Abort: process excel sheet...\n\n",'SE');
    exit;
  }
  
  # get cvterm_ids
  my $cvterm_ref = getCVtermIDs('contact', $module_ref, $data_info_ref);
  
  # insert/update data
  foreach my $ctr (sort { $a <=> $b } keys %{$excel_ref}) {
    println(sprintf("\n$module_ref->{SHEET} [ROW : %d]\n",$ctr+2),'WE');
    
    # ------------------------------------------- #
    # insert into contact tables
    # ------------------------------------------- #
    # contact_type, name, research_interests
    my $contact_type_id = get_cvterm_id($excel_ref->{$ctr}{contact_type}, 
                                        $data_info_ref->{CV_ID});
#print "Contact type id for '$excel_ref->{$ctr}{contact_type}' is $contact_type_id\n";
    my ($contact_id, $update) 
      = insert_into_contact($contact_type_id, 
                            $excel_ref->{$ctr}{name}, 
                            $excel_ref->{$ctr}{research_interests});
print "Returned from insert: contact_id: $contact_id, update record: $update\n";
    continue if ($contact_id == 0); # something went wrong with this record.
    
    # ------------------------------------------- #
    # insert into contactprop tables
    # ------------------------------------------- #
    # first_name
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{first_name}, 
                            $excel_ref->{$ctr}{first_name}, 
                            $update) if ($excel_ref->{$ctr}{first_name});
    # last_name
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{last_name}, 
                            $excel_ref->{$ctr}{last_name}, 
                            $update) if ($excel_ref->{$ctr}{last_name});
    # title
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{title}, 
                            $excel_ref->{$ctr}{title}, 
                            $update) if ($excel_ref->{$ctr}{title});
    # affiliation
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{affiliation}, 
                            $excel_ref->{$ctr}{affiliation}, 
                            $update) if ($excel_ref->{$ctr}{affiliation});
    # lab
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{lab}, 
                            $excel_ref->{$ctr}{lab}, 
                            $update) if ($excel_ref->{$ctr}{lab});
    # address
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{address}, 
                            $excel_ref->{$ctr}{address}, 
                            $update) if ($excel_ref->{$ctr}{address});
    # country
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{country}, 
                            $excel_ref->{$ctr}{country}, 
                            $update) if ($excel_ref->{$ctr}{country});
    # email
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{email}, 
                            $excel_ref->{$ctr}{email}, 
                            $update) if ($excel_ref->{$ctr}{email});
    # phone
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{phone}, 
                            $excel_ref->{$ctr}{phone}, 
                            $update) if ($excel_ref->{$ctr}{phone});
    # fax
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{fax}, 
                            $excel_ref->{$ctr}{fax}, 
                            $update) if ($excel_ref->{$ctr}{fax});
    # url
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{url}, 
                            $excel_ref->{$ctr}{url}, 
                            $update) if ($excel_ref->{$ctr}{url});
    # research_interests
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{research_interests}, 
                            $excel_ref->{$ctr}{research_interests}, 
                            $update) if ($excel_ref->{$ctr}{research_interests});
    # last_update
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{last_update}, 
                            $excel_ref->{$ctr}{last_update}, 
                            $update) if ($excel_ref->{$ctr}{last_update});
    # comments
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{comments}, 
                            $excel_ref->{$ctr}{comments}, 
                            $update) if ($excel_ref->{$ctr}{comments});
    insert_into_contactprop($contact_id, 
                            $cvterm_ref->{curator_comments}, 
                            $excel_ref->{$ctr}{curator_comments},
                            $update) if ($excel_ref->{$ctr}{curator_comments});
      
    # save name code in hash
    $name_code_ref->{$excel_ref->{$ctr}{name_code}} = $contact_id;
    
    # alias
    my @aliases= split(/[,;]/, $excel_ref->{$ctr}{alias});
    my $rank= 0;
    foreach my $alias (@aliases) {
      insert_into_contactprop($contact_id, 
                              $cvterm_ref->{alias}, 
                              $pg_db->trim_quote($alias), 
                              $update,
                              $rank++);
    }
  }#each contact record
}#process_contact

1;
__END__