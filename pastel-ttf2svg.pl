#! /usr/bin/perl -w

###################################################################
# This is my attempt to make a ttf2svg program in perl. More in the
# line of ttf2svg converter of BATIK
# Copyright (c) 2002, Malay <curiouser@gene.ccmbindia.org>
# This program is licenced as Perl itself
# Send your bug reports to me.
###################################################################

use POSIX; # For floor() and ceil()
use strict;
use Getopt::Std;

my $PLATFORM_ID = 3;
my $ENCODING_ID = 1;
#my $LANGUAGE = 1033; #American english 0x0409
my $FILENAME = "";
my $first_character = 32;
my $last_character = 255;
my $ID ="";
my $IT_IS_A_TEST = 0;
my @TEST_GLYPHS;
my @glyph_index;
my @post_glyph_name;
my @glyph_name_index;
my @mac_glyph_name;
my $SVG = ""; # Holds the whole string;

my %table; # Holds table offset

#my %kern; # Key is a packed 32 bit number of the left and the right
          # Glyph and value is kern value

my %kern_to_print; # Hold the kern keys to print for the present
                   # charcater range
our %opts;
getopt("flhi", \%opts);

if (defined $opts{s}){
  #print "DEFINED SYMBOL\n";
  $first_character = 61472;
  $last_character = 61695;
  $ENCODING_ID = 0;
}
if ( !defined $opts{"f"} ){
   print_instructions();
   exit 1;
}

if ( $opts{"f"} eq "1" ){
   die print_instructions();
}else {
  $FILENAME = $opts{"f"};
}

open (INFILE, $FILENAME) || die "Can't open input file $FILENAME!\n";
binmode INFILE;

if ( defined $opts{l} ){
  if( $opts{l} > 1 ){
    $first_character = $opts{l};
  } else {
    die print_instructions();
}
}

if ( defined $opts{h} ){
  if( $opts{h} > 1 ){
    $last_character = $opts{h};
  } else {
    die print_instructions();
}
}

if ( defined $opts{i} ){
  if( $opts{h} ne "1" ){
    $ID = $opts{i};
  } else {
    die print_instructions();
}
}

if( defined $opts{t}){
  $IT_IS_A_TEST = 1;
}
  

#if ( defined ($ARGV[1]) ) {
#    open (OUT, ">$ARGV[1]" ) || die "Can't open output file!\n";
#}


directory_entry();
make_glyph_index();
make_ps_name_table();
make_mac_glyph_name();

#make_loca()
write_svg_begin(); # Write DTD and XML declaration
write_svg_font();
print $SVG;
#print $glyph_index[36], "***",get_glyph_data($glyph_index[36]),"\n";
#print "@kern_to_print ";
close(INFILE) || die "Could not close file!\n";


  
sub write_svg_begin
{
    $SVG .= "<?xml version=\"1.0\" standalone=\"no\"?>\n";
    $SVG .= '<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20001102//EN" "http://www.w3.org/TR/2000/CR-SVG-20001102/DTD/svg-20001102.dtd" >';
    $SVG .= "\n";

    $SVG .= "<svg width=\"100%\" height=\"100%\">";
    $SVG .= "\n<defs>";
    $SVG .= "\n";
}

sub write_svg_font
  {
     my  $advance = get_horiz_adv_x();
     $SVG .= "<font ";
     if ( $ID ne "" ){
       $SVG .="id=\"$ID\" ";
} 
     $SVG .= "horiz-adv-x=\"$advance\">\n";

     my $family_name = get_font_family();
     $SVG .= "<font-face font-family=\"$family_name\" ";

     my $units_per_em = get_units_per_em();
     $SVG .="units-per-em=\"$units_per_em\" ";

     my @panose = get_panose();
     my $s = join (" ", @panose);
     $SVG .="panose-1=\"$s\" ";

     my $ascent = get_ascent();
     $SVG .="ascent=\"$ascent\" ";

     my $descent = get_descent();
     $SVG .="descent=\"$descent\" baseline=\"0\" />\n";
    # $s  = get_glyph_data(0);
     $SVG .= "<missing-glyph horiz-adv-x=\"".get_advance_width(0)."\" d=\"".get_glyph_data(0)."\" />\n";

     for (my $i = $first_character; $i < $last_character+1; $i++){
	 my $char;
	# if( $i < $last_character){
#	  $kern_to_print[scalar(@kern_to_print)] 
#	    = pack_left_and_right($glyph_index[$i], $glyph_index[$i+1]);
#	      #print "GLYPH: $glyph_index[$i]\n";                                         
#	}
	# if($i > 126 && $i < 160 ){
#	   next;
#	 }
	 
	 if ($i > 126  && $i < 256){
	   $char = "&#x".unpack("H2",pack("I",$i)).";";
	 }elsif ( $i >= 256){
	      $char = "&#x".unpack("H4",pack("n",$i)).";";
	 }else {
	   $char = pack ("C", $i);
	   my $encoded = encode_entity($char);
           if ($encoded) {
	       $char = $encoded;
	   }
	  }
	$TEST_GLYPHS[scalar(@TEST_GLYPHS)] = $char;
	$SVG .="<glyph unicode=\"$char\"";
	$SVG .=" horiz-adv-x=\"".get_advance_width($glyph_index[$i])."\"";
	$SVG .=" glyph-name=\"".get_glyph_name($glyph_index[$i])."\"";
	 $kern_to_print{$glyph_index[$i]}=" ";
	 if($PLATFORM_ID == 3){
	   if( $i == 32 || $i== 160){
	     $SVG .= "/>\n";
	     next;
	   }else {
	     my $g = get_glyph_data($glyph_index[$i]);
	     if( $g ){
	     $SVG .= " d=\"".$g."\""; #test($i, $g);} 
	   }
	     $SVG .= "/>\n";
	   }
	 }
	 
	 #if (!$g){ test($i); }
	 #print $glyph_index[$i],"\t", get_path_as_svg($glyph_index[$i]), "\n";
       }
     if ( exists ($table{"kern"})){
     $SVG .=process_kern_table();
   }
    # write_kern_data();
     $SVG .= '</font>';
     $SVG .= "\n";
     $SVG .= '</defs>';
     $SVG .= "\n";

     if( $IT_IS_A_TEST == 1){
       $SVG .= print_test();
     }
     $SVG .= '</svg>';
     
 }

#sub pack_left_and_right {
#  my $l = shift;
#  my $r = shift;
#  my $s = ( (($l & 0xFFFF) << 16) | (($r & 0xFFFF) << 0));
#  #print $s, "\n";
#  return $s;
#}

sub get_horiz_adv_x {
    my $OS2 = $table{'OS/2'};
   # print "****OS2 = $OS2\n";
    my $buf;
    seek (INFILE, $OS2, 0);
    read (INFILE, $buf, 4);
    my($adv) = unpack("x2n", $buf);
    #print "****$adv\n";
    return $adv;
}

sub directory_entry {
    my $buf;
    read(INFILE, $buf, 12);
    my ($version, $number) = unpack("Nn", $buf);
    #print "Version = $version, Number of tables = $number\n";
    # print "\nTABLE\tOFFSET\tLENGTH\n";

    for(my $i = 0; $i < $number; $i++){
    #print "Inside for\n";
     read(INFILE, $buf, 16);
     my ( $table, $offset, $length) = unpack("a4x4NN", $buf);
     $table{$table} = $offset;
     
#print "$table\t$offset\t$length\n";
}
    #print $table{'OS/2'};
}

sub get_font_family {
    my $buf;

   my  $LANGUAGE_ID;
    
    if ( $PLATFORM_ID =="1" && $ENCODING_ID =="0"){
	$LANGUAGE_ID = 0;
    }
    else {
	$LANGUAGE_ID = 1033;
    }
    my $add = $table{'name'};
    seek (INFILE, $add, 0);
    read(INFILE, $buf, 6);
    my ( $num , $offset) = unpack ("x2nn", $buf);
    #print "*******NAME : Number of records, $num, Offset: $offset\n";

    my ($copyright_offset, $font_family_name_offset,
	$subfamily_offset, $id_offset,$full_name_offset,
	$version_string_offset, $postscript_offset, $trademark_offset);

    my ($copyright_length, $font_family_length,
	$subfamily_length, $id_length, $full_name_length,
	$version_length, $postscript_length, $trademark_length);
    
    for (my $i = 0; $i < $num; $i++){
	read (INFILE, $buf, 12);
	my ($id, $encoding, $language, $name_id, $length, $string_offset)
	   = unpack("n6", $buf);
	#print "****NAMERECORDS: $id, $encoding, $language, $name_id, $length, $string_offset\n";

	if ( ($id == $PLATFORM_ID)&&         # Windows??
	     ($encoding == $ENCODING_ID) &&  #UGL??
	     ($language == $LANGUAGE_ID)
	   ) {
	    if ($name_id == 0 ) { #Copyright
		$copyright_offset = $string_offset;
		$copyright_length = $length;
	    }
	    if ($name_id == 1 ) { # Familyname
		$font_family_name_offset = $string_offset;
		$font_family_length =  $length;
	    }
	    if ($name_id == 2 ) { # Subfamily
		$subfamily_offset = $string_offset;
		$subfamily_length = $length;
	    }
	    if ($name_id == 3 ) { # Identifier
		$id_offset = $string_offset;
		$id_length = $length;
	    }
	    if ($name_id == 4 ) { # Full name
	        $full_name_offset = $string_offset;
		$full_name_length = $length;
	    }
	    if ($name_id == 5 ) { #version string
		$version_string_offset = $string_offset;
		$version_length = $length;
	    }
	    if ( $name_id == 6) { # Postscript name
		$postscript_offset = $string_offset;
		$postscript_length = $length;
	    }
	    if ($name_id == 7 ) { # Trademark
		$trademark_offset = $string_offset;
 		$trademark_length = $length;
	    }
	}

    } # End for loop;

    # Print copyright
    seek ( INFILE, $table{'name'} + $offset + $copyright_offset, 0);
    read (INFILE, $buf, $copyright_length);
   # print "COPYRIGHT: $buf\n\n";

    # Print familyname
    seek (INFILE, $table{'name'} + $offset + $font_family_name_offset, 0 );
    read ( INFILE, $buf, $font_family_length);
    my @char = unpack("C*",$buf);
    my $i = $font_family_length;
   my $s = "";
    my $j = 0;
    while ( $j < $i){  
      if (defined $char[$j+1]){
      $s .= pack("C",$char[$j+1]);}
      $j += 2;
    }
    #print $s;
    return  $s;
    #print  "\n****", "@char", "*****\n"; 
    #return "@char";
# print "FAMILY: $buf\n\n";
    
    #Print Subfamily
    seek (INFILE, $table{'name'} + $offset + $subfamily_offset, 0);
    read (INFILE, $buf, $subfamily_length);
    #print "SUBFAMILY: $buf\n\n";

    #Print Identifier
    seek ( INFILE, $table{'name'} + $offset +$id_offset, 0);
     read (INFILE, $buf, $id_length);
    #print "ID: $buf\n\n";

    #Print Full name
    seek ( INFILE, $table{'name'} + $offset +$full_name_offset, 0);
     read (INFILE, $buf, $full_name_length);
    #print "FULL NAME: $buf\n\n";

    #Print Version string
    seek ( INFILE, $table{'name'} + $offset +$version_string_offset, 0);
     read (INFILE, $buf, $version_length);
    #print "VERSION: $buf\n\n";


    #Print Postscript
    seek ( INFILE, $table{'name'} + $offset +$postscript_offset, 0);
     read (INFILE, $buf, $postscript_length);
    #print "Postscript: $buf\n\n";

#Print Trademark
    seek ( INFILE, $table{'name'} + $offset +$trademark_offset, 0);
     read (INFILE, $buf, $trademark_length);
    #print "TRADEMARK: $buf\n\n";


}

sub get_units_per_em {

    # Get Headtable address
    my $buf;
    seek(INFILE, $table{"head"}, 0);

    read(INFILE, $buf, 54) == 54 || die "reading head table";
    my($units_per_em, $index_to_loc) = unpack("x18nx30n", $buf);

   # print "Unit/EM: $units_per_em\tIndex_to_loc: $index_to_loc\n\n";

    return $units_per_em;
}


sub get_panose {
    my $buf;
    seek (INFILE, $table{'OS/2'}, 0);
    read(INFILE, $buf, 42);

    #Throw away first 32 bytes and take last 10

    my (@panose) = unpack ("x32c10", $buf);
    return @panose;
}

sub get_ascent {
    my $buf;
    seek(INFILE, $table{hhea}, 0);
    read(INFILE,$buf,6);
    my $ascender = unpack("x4n", $buf);
    return $ascender - ($ascender > 32768 ? 65536 : 0);
}

sub get_descent {
    my $buf;
    seek(INFILE, $table{hhea}, 0);
    read(INFILE,$buf,8);
    my $descender = unpack("x6n", $buf);
    return $descender - ($descender > 32768 ? 65536 : 0);
}

sub encode_entity {
    my $char = shift;
    if ( $char eq '<'){
	return "&lt;";
    }

    if ($char eq '>'){
	return "&gt;";
    }

    if ($char eq "'"){
	return "&apos;";
    }

    if($char eq '"'){
	return "&quot;";
    }

    if ($char eq '&'){
	return "&amp;";
    }
}

sub make_glyph_index {
    my $buf;
    my $offset;
    
    # Glyph indices are stored in "cmap" table. We get the offset of the
    # "cmap" table from the %table hash

    my $cmap = $table{'cmap'};

    #Go there
    seek (INFILE, $cmap, 0);

    #'cmap' table starts with
    # USHORT    Table version number
    # USHORT    Number of encoding tables
    # Read 4 bytes
    read (INFILE, $buf, 4);

    #Get number of tables and skip the version number
    my ($num) = unpack ("x2n", $buf);

    # Read the tables. There will $num tables
    # Each one for a specific encoding and platform id
    # There are three most important id and encoding-
    # Windows        :      ID=3    Encoding = 1
    # Windows symbol :      ID=3    Encoding = 0
    # Mac/Poscript   :      ID=1    Encoding = 0

    #Each subtable:
    # USHORT         Platform ID
    # USHORT         Platform specific encoding ID
    # ULONG          Byte ofset from the begining of the 'cmap' table
    
    for(my $i = 0; $i < $num; $i++){
       read(INFILE, $buf, 8); 
       my($id, $encoding, $off) = unpack("nnN", $buf);
       #print $id , "\n";
       #print $encoding , "\n";

       if($id == $PLATFORM_ID && $encoding == $ENCODING_ID){
	 #print "Match Found ", $id, "\n";
	# print "Offset: $off\n";
              $offset = $off;
	 seek(INFILE, $table{'cmap'} + $offset, 0);
       }
     }

    #Goto the specific table
    

    # Mac/Poscript table with encoding 0 use the following format
    # USHORT    format set to 0
    # USHORT    length
    # USHORT    version starts at 0
    # BYTE      glyphIdArray[256] There is no trick here just read the whole
    #           thing as 256 array

    # If MAC/Postcript table
    if ($PLATFORM_ID =="1" && $ENCODING_ID=="0"){
	# Skip the format, length and version information
	read(INFILE, $buf, 6);
	#print (unpack("nnn", $buf));
	# Now read the 256 element array directly

	for (my $i =0; $i < 256; $i++){
	    read(INFILE, $buf,1);
	    #print $buf;
	    $glyph_index[$i] = unpack("C", $buf);
	    #print $glyph_index[$i];
	    print "Char $i\t\t-> Index $glyph_index[$i]\n";
	}

      }

    # Windows  table with encoding 1 use the following format FORMAT 4
 #   USHORT         format                 Format number is set to 4. 
#    USHORT         length                 Length in bytes. 
#    USHORT         version                Version number (starts at 0).
#    USHORT         segCountX2             2 x segCount.
#    USHORT         searchRange            2 x (2**floor(log2(segCount)))
#    USHORT         entrySelector          log2(searchRange/2)
#    USHORT         rangeShift             2 x segCount - searchRange
#    USHORT         endCount[segCount]     End characterCode for each segment,
#                                           last =0xFFFF.
#    USHORT         reservedPad            Set to 0.
#    USHORT         startCount[segCount]   Start character code for each segment.
#    USHORT         idDelta[segCount]      Delta for all character codes in segment.
#    USHORT         idRangeOffset[segCount]Offsets into glyphIdArray or 0
#    USHORT         glyphIdArray[ ]        Glyph index array (arbitrary length)
    
    if ( $PLATFORM_ID == 3){
	 read (INFILE, $buf, 6);
	 my ($format, $length, $version) = unpack("nnn", $buf);
	 #print "Format: $format\tLength: $length\tVersion: $version\n\n";
	 read (INFILE, $buf,8);
	 my ($seg_countX2, $search_range, $entry_selector, $range_shift)  
	   = unpack("nnnn", $buf);
	 my $seg_count = $seg_countX2 / 2;
	 #print "SegcountX2:\t\t$seg_countX2\n";
	 #print "Search Range:\t$search_range\n";
	 #print "Entry:\t$entry_selector\n";
	 #print "Range Shift:\t$range_shift\n";
    
	 read(INFILE, $buf, 2 * $seg_count);
	 my(@end_count) = unpack("n" x $seg_count, $buf);
	 #print "EndCount: ", join("\t",@end_count), "\n";
	 read(INFILE, $buf, 2);
	 my $reserve_pad = unpack("n", $buf);
	 #print "Reserve Pad: $reserve_pad\n";

	 read(INFILE, $buf, 2 * $seg_count);
	 my(@start_count) = unpack("n" x $seg_count, $buf);
	 #print "Start Count: ", join("\t",@start_count), "\n";

	 read(INFILE, $buf, 2 * $seg_count);
	 my(@id_delta) = unpack("n" x $seg_count, $buf);
	 #print "idDelta: ", join("\t",@id_delta), "\n";

	 read(INFILE, $buf, 2 * $seg_count);
	 my(@id_range_offset) = unpack("n" x $seg_count, $buf);
	 #print "idRangeOffset: ", join("\t",@id_range_offset), "\n";

	 my $num = read(INFILE, $buf, $length - ($seg_count * 8) - 16);
	 my (@glyph_id) = unpack("n" x ($num / 2), $buf);

	 my $i;
	 my $j;
	 #print "Last count:", $end_count[$#end_count], "\n";
	 for ( $j = 0; $j <$seg_count; $j++){
	 for (  $i = $start_count[$j]; $i <= $end_count[$j]; $i++){
	   #print $start_count[$j], "****", $end_count[$j], "\n";

		 #if ($end_count[$j] >= $i && $start_count[$j] <= $i){
		     #print "ID RANGE OFFSET $id_range_offset[$j]", "\n";
		     if ($id_range_offset[$j] != 0){
			 
			 $glyph_index[$i] = $glyph_id[$id_range_offset[$j]/2 + ($i - $start_count[$j]) - ($seg_count - $j)];
		     }
		     else {
			$glyph_index[$i] = ($id_delta[$j] + $i) % 65536;
		       
		       }
		   
	   if (!defined($glyph_index[$i])){
	       #$glyph_index[$i] = $glyph_id[0];
	       $glyph_index[$i] = 0;
	     }
		   }
       }
	     
       for ( my $i = $first_character; $i <= $last_character; $i++){
	   if ( !defined($glyph_index[$i])){
	     $glyph_index[$i] = 0;
	   }
	 }
       }
}
#Returns the advanced with of a particular glyph given the glyph index
sub get_advance_width {
    my $buf;
    seek(INFILE, $table{"hhea"}, 0);
    read(INFILE, $buf, 36) == 36 || die "reading hhea table";
    my($h_num) = unpack("x34n", $buf);
    my $num = $h_num;
    
    my $index = shift;
    #print "INDEX:$index", "\n";
    seek(INFILE, $table{"hmtx"}, 0);
    read(INFILE, $buf, 4 * $num) == 4 * $num || die "reading hmtx table";
    my (@h_temp) = unpack("n" x (2 * $num), $buf);
   # print "******@h_temp\n";
    my (@advanced_width);
    my (@lsb);
    for (my $i = 0; $i < @h_temp; $i +=2){
        push (@advanced_width,$h_temp[$i]);
        #print $h_temp[$i];
    }
    for (my $i = 1; $i < @h_temp; $i +=2){   
        push (@lsb,$h_temp[$i]);
    }
#print @advanced_width, "\n";
#print @lsb;
    if ( !defined($advanced_width[$index])){
      $index = $#advanced_width;
    }
    if($index > @advanced_width ){ #print "Index greater than advanced width\n";
      $index = $#advanced_width;}
    if ($index > @lsb){$index = $#lsb;}
    #print "\"$advanced_width[$index]\"", "***", "\n";
    my $a = $advanced_width[$index] - ($advanced_width[$index] > 32768 ? 65536 : 0);
    #my $l = $lsb[$index] - ($lsb[$index] > 32768 ? 65536 :0);
    
    #return $a, $l;
    return $a;
 }


# Returns the glyph path as SVG fragment when supplied with the glyph index
# Ist parameter in the character number
# If the second parameter is TRUE then return on the coordinates
# Otherwise return SVG formatted data

sub get_glyph_data{
    my $index = $_[0];
    my $buf;
    my $num_of_points;
    my @end_points;
    my @x;
    my @y;
    my @on_path; # Stores 0, 1 depending on whether the point is on path or not
    my @flags;
    my @size; #Short or byte for coordinates

    my  $units_per_em = get_units_per_em($index);
    my $glyph_location = loca_get_glyph_location($index);
    
    seek (INFILE, $table{"glyf"} + $glyph_location, 0);
    read(INFILE, $buf, 10);
    my (@array) = unpack("nnnnn", $buf);
    my $number_of_contours = $array[0] - ($array[0] > 32768 ? 65536 : 0);
    #print "NUMBER OF CONTOURS: $number_of_contours\n";
# read(INFILE, $buf, 2 * $number_of_contours);
#	 (@end_points) = unpack("n" x $number_of_contours, $buf);
#	#print "END POINTS:@end_points", "\n";
#	 $num_of_points = $end_points[$#end_points] + 1;
#	read(INFILE, $buf, 2);
#	my ($instruction_length) = unpack("n", $buf);
	
##print $instruction_length, "\n";
#	if($instruction_length == 0){
#	  return "";
#	}
    if($number_of_contours >= 0 ){ # It is a simple glyph
	if($number_of_contours == 0){
	  #print "*************NO CONTOURS*********\n";  
	  return undef;
	} elsif ( $number_of_contours != 0){   
	  my @s =  get_simple_glyph_coord($index);
	  #print "@s\n";
	  if($s[0]){
	  #print "**** Before calling path \n";
	    return get_path_as_svg (@s);
	} else { return undef;
	  #print get_simple_glyph_coord($number_of_contours);
	}} else {
	  die " In getting Glyph data \n";
}
    }

    if($number_of_contours < 0){
	
       return get_composite_glyph($index);
	
    }
  #print @x;
}

sub get_path_as_svg {
#print @_;
  #my $index = shift;
  my @x = @{$_[0]};
  my @y = @{$_[1]};
  my @on_path = @{$_[2]};
  my @end_points = @{$_[3]};

 # print "X: ", "@x", "\n";
  #print "y: ", "@y", "\n";
 

  
#  for(my $i = 0; $i < @x; $i++){
#    if($i> 0){
#      $x[$i] = $x[$i] + $x[$i-1];
#      $y[$i] = $y[$i] + $y[$i-1];

#    }
#  }
  #print "FUNCTION";
  #print "Absolute: ", join(" ", @x), "\n";

  my $s = "";

  my $start;
  my $stop;
  my $j = 0;
  
  for(my $i = 0; $i < @end_points; $i++){
    if($end_points[$i] == 0){
      print "END POINT REACHED\n";
      return undef;
    }
    if( $i == 0){ $start = 0; $stop = $end_points[$i]+1; }
    else { $start = $stop; $stop = $end_points[$i]+1;}
    #print "Start =", $start," ", "Stop= ", $stop,"\n";
    
   
    while($j < $stop){
      my $point;
      my $point1;
      my $point2;
      
      if( $j == $stop -1){
	$point = $j;
	$point1 = $start;
	$point2 = $start+1;
      } elsif($j == $stop-2){
	$point = $j;
	$point1 = $j+1;
	$point2 = $start;
      }else{
	$point = $j;
	$point1 = $j+1;
	$point2 = $j+2;
      }
    
      if($point == $start){
	$s .= "M".$x[$j]." ".$y[$j];
      }
      
      if($on_path[$point]==1 && $on_path[$point1]==1){
	if($x[$point]==$x[$point1]){
	  $s .= "V".$y[$point1];
	} elsif ($y[$point]==$y[$point1]){
	  $s .= "H".$x[$point1];
	} else {
	  $s .= "L".$x[$point1]." ".$y[$point1];
	}
	$j++;
      } elsif($on_path[$point]==1 && $on_path[$point1]==0 &&
	      $on_path[$point2]==1)
	{
	  $s .= "Q".$x[$point1]." ".$y[$point1]
	    ." ".$x[$point2]." ".$y[$point2];
	  $j = $j +2;
	} elsif($on_path[$point]==1 && $on_path[$point1] ==0
		&& $on_path[$point2] == 0)
	  {
	    $s .= "Q".$x[$point1]." ".$y[$point1]
	      ." ".mid_value($x[$point2],$x[$point1])." ";
	    $s .= mid_value($y[$point2],$y[$point1]);
	  $j += 2; 
	  } elsif($on_path[$point] == 0 && $on_path[$point1] == 0){
	    $s .= "T".mid_value($x[$point],$x[$point1])." ";
	    $s .=mid_value($y[$point],$y[$point1]);
	    $j++;
	  } elsif ($on_path[$point]== 0 && $on_path[$point1] == 1){
	    $s .= "T".$x[$point1]." ".$y[$point1];
	    $j++;
	  } else {
	    print "Not catered for\n";
	    last;
}
    }

    $s .= "Z";
	    
  }
	
 return $s;	
}
sub get_simple_glyph_coord {
  my $buf;
  my $repeat = 0x08;
    my $on_curve=0x01;
    my $x_short_vector = 0x02;
    my $y_short_vector = 0x04;
    my $x_dual = 0x10;
    my $y_dual = 0x20;
    my $index = shift;
    #print "INDEX : $index\n";
  my @x;
    my @y;
    my @on_path; # Stores 0, 1 depending on whether the point is on path or not
    my @flags;
    my @size; #Short or byte for coo

  my $glyph_location = loca_get_glyph_location($index);
  my $next_glyph     = loca_get_glyph_location($index + 1);
  
  if ( $glyph_location == $next_glyph ){
    return undef;
  }
   #print "GLYPH LOCATION: $glyph_location\n"; 
    seek (INFILE, $table{"glyf"} + $glyph_location, 0);
    read(INFILE, $buf, 10);
    my (@array) = unpack("nnnnn", $buf);
    my $number_of_contours = $array[0] - ($array[0] > 32768 ? 65536 : 0);
    #print $number_of_contours , "\n";
    read(INFILE, $buf, 2 * $number_of_contours);
	my  (@end_points) = unpack("n" x $number_of_contours, $buf);
	#print "END POINTS:@end_points", "\n";
	my $num_of_points = $end_points[$#end_points] + 1;
	read(INFILE, $buf, 2);
	my ($instruction_length) = unpack("n", $buf);
	#print $instruction_length, "\n";
#	if($instruction_length == 0){
#	  return undef;
#	}

	read (INFILE, $buf, $instruction_length);
	my $repeats;
	#Read flags
	for (my $i = 0; $i < $num_of_points; $i++){
 	    read (INFILE, $buf, 1);
	    $flags[$i] =ord( $buf);
	    if ( ($flags[$i] & $repeat) != 0 ){
		read(INFILE, $buf, 1);
		$repeats = ord($buf);

		for ( my $j = 1; $j <= $repeats;$j++){
		    $flags[$i + $j] = $flags[$i];
		}
		$i +=$repeats;
	    }
	 
	}

	for (my $i =0; $i <@flags; $i++){
	    my $s = $i;
	    if ( ($flags[$i] & $on_curve) != 0){
		$on_path[$i] = 1;
	      
	      #$s .="\ton";
	    } else {
	      $on_path[$i] = 0;
	      #$s .="\toff";
	      }

	    if( ($flags[$i] & $x_dual) != 0) {
		$s .="\tx_dual";
	    }
	    if( ( $flags[$i] & $y_dual) != 0){
		$s .="\ty_dual";
	    }
	    if( ( $flags[$i] & $x_short_vector) != 0){
		$s .="\tx_short";
	    }
	    if( ( $flags[$i] & $y_short_vector) != 0){
		$s .="\ty_short";
	    }
	    $s .="\n";
	    #print "\n\n******","\n", $s;
}


	
	#my $x =0;
	#my $y = 0;
	#Read coodinates
	for (my $i = 0; $i < $num_of_points; $i++){
	    my $x = 0;
	    if( ($flags[$i] & $x_dual) != 0){
		#print "**x_dual true\n";
		if( ($flags[$i] & $x_short_vector) != 0 ){
		    read (INFILE, $buf,1);
		    $x = ord($buf);
		}
	    } else {
		if( ($flags[$i] & $x_short_vector) != 0) {
		    read (INFILE, $buf, 1);
		    $x = -(ord( $buf));
		} else {
		    read (INFILE, $buf,1);
		    my $temp = ord($buf);
		    read (INFILE, $buf, 1);
		    $x = ($temp << 8 | ord($buf));
		}
	    }
	    #print "**$x  ";
	    $x[$i] = $x - ($x > 32768 ? 65536 : 0);
	}

	for ( my $i = 0; $i < $num_of_points; $i++){
	    my $y = 0;
	    if( ($flags[$i] & $y_dual) != 0 ){
		if ( ($flags[$i] & $y_short_vector) != 0){
		    read(INFILE, $buf, 1);
		    $y = ord($buf);
		}
	    } else {
		if( ($flags[$i] & $y_short_vector) != 0 ){
		    read (INFILE, $buf, 1);
		    $y = -ord($buf);
		} else {
		    read (INFILE, $buf, 1);
		    my $temp = ord($buf);
		    read(INFILE, $buf, 1);
		    $y = ($temp << 8 | ord($buf));
		}

	    }
	    $y[$i] = $y - ($y > 32768 ? 65536 : 0);
	    #print $y[$i],"\n";
	}

	#print "\n","X-Cord:\n",join(" ", @x),"\n";
	#print "\n", "Y-Cord:\n",join(" ", @y),"\n";
#    print "\n","On-path:\n", join(" ",@on_path), "\n";
#	print "\n", "End-Points:\n", join(" ", @end_points), "\n";

    for(my $i = 0; $i < @x; $i++){
    if($i> 0){
      $x[$i] = $x[$i] + $x[$i-1];
      $y[$i] = $y[$i] + $y[$i-1];

    }
  }
	return (\@x, \@y, \@on_path, \@end_points); 
 
    }



sub get_composite_glyph {
    my $index = shift;
    #print $index, "\n";
  my $ARG_1_AND_2_ARE_WORDS = 0x0001;
    my $ARGS_ARE_XY_VALUES    = 0x0002;
    my $ROUND_XY_TO_GRID      = 0x0004;
    my $WE_HAVE_A_SCALE       = 0x0008;
    my $MORE_COMPONENTS       = 0x0020;
    my $WE_HAVE_AN_X_AND_Y_SCALE = 0x0040;
    my $WE_HAVE_A_TWO_BY_TWO  = 0x0080;
    my $WE_HAVE_INSTRUCTIONS  = 0x0100;
    my $USE_MY_METRICS        = 0x0200;
    my $flags = 0;
    my $s = "";
    my $buf;
 my $glyph_location = loca_get_glyph_location($index);
  seek (INFILE, $table{"glyf"} + $glyph_location, 0);
    read(INFILE, $buf, 10);
    my (@array) = unpack("nnnnn", $buf);
    my $number_of_contours = $array[0] - ($array[0] > 32768 ? 65536 : 0);
    
       my $count = 0;
       my @glyph_index; 
       my $argument1;
	my    $argument2;
	my    @xtranslate;
	my    @ytranslate;
	my    @point1;
	my    @point2;
        my @xscale;
        my @yscale;
#	my    $xscale= 1.0;
#	my    $yscale = 1.0;
	my   @scale01;
	my   @scale10;
do{
     
  #my $buf;
  my $scale;
 
  read (INFILE, $buf, 2);
	 $flags = unpack("n", $buf);
	read(INFILE, $buf, 2);
	$glyph_index[scalar(@glyph_index)] = unpack("n", $buf);
	#print "Composite:",  "@glyph_index\n";
	
	if( ($flags & $ARG_1_AND_2_ARE_WORDS) != 0){
	 
	  read(INFILE, $buf, 2);
	    $argument1 = unpack("n", $buf);
	    read(INFILE, $buf, 2);
	    $argument2 = unpack("n", $buf);
	} else {
	  #print "ARGUMENT 1 & 2 ARE NOT WORDS\n"; 
	  read(INFILE, $buf, 1);
	    $argument1 = unpack("C", $buf);
	    read (INFILE, $buf, 1);
	    $argument2 = unpack("C",$buf);
	}
  $argument1 = $argument1 - ($argument1 > 32768 ? 65536 : 0);  
   $argument2 = $argument2-($argument2 > 32768 ? 65536 : 0);
    #print "ARGUMENT1:", $argument1, "\n";
      #print "ARGUMENT2:", $argument2, "\n";
  
	if( ($flags & $ARGS_ARE_XY_VALUES) != 0 ){
	  #print " ARGS ARE XY VALUES\n";  
	  #print "ARGUMENT1: $argument1\n";
	  $xtranslate[scalar(@xtranslate)] = $argument1;
	  #print '$xtranslate called', "\n";
	  #print "@xtranslate" , "\n";
	    $ytranslate[scalar(@ytranslate)] = $argument2;
	} else {
	    $point1[scalar(@point1)] = $argument1;
	    $point2[scalar(@point2)] = $argument2;
	}

	if ( ($flags & $WE_HAVE_A_SCALE) != 0 ){
	  #print "We have a scale\n";  
	  read (INFILE, $buf, 2);
	    $scale = unpack("n", $buf);
	    $scale = $scale - ($scale > 32768 ? 65536 : 0);  
	    $xscale[scalar(@xscale)] = $scale / 0x4000;
	    $yscale[scalar(@yscale)] = $xscale[$#xscale];
	} elsif ( ($flags & $WE_HAVE_AN_X_AND_Y_SCALE) != 0 ){
	    read (INFILE, $buf, 2);
	    $scale = unpack("n", $buf);
	     $scale = $scale - ($scale > 32768 ? 65536 : 0);  
	    $xscale[scalar(@xscale)] = $scale / 0x4000;
	    read (INFILE, $buf, 2);
	    $scale = unpack("n", $buf);
	     $scale = $scale - ($scale > 32768 ? 65536 : 0);  
	    $yscale[scalar(@yscale)] = $scale / 0x4000;
	} elsif ( ($flags & $WE_HAVE_A_TWO_BY_TWO) != 0){
	    read (INFILE, $buf, 2);
	    $scale = unpack("n", $buf);
	     $scale = $scale - ($scale > 32768 ? 65536 : 0);  
	    $xscale[scalar(@xscale)] = $scale / 0x4000;
	    read (INFILE, $buf, 2);
	    $scale = unpack("n", $buf);
	     $scale = $scale - ($scale > 32768 ? 65536 : 0);  
	    $scale01[scalar(@scale01)] = $scale / 0x4000;
	     read (INFILE, $buf, 2);
	    $scale = unpack("n", $buf);
	     $scale = $scale - ($scale > 32768 ? 65536 : 0);  
	    $scale10[scalar(@scale10)] = $scale / 0x4000;
	    read (INFILE, $buf, 2);
	    $scale = unpack("n", $buf);
	     $scale = $scale - ($scale > 32768 ? 65536 : 0);  
	    $yscale[scalar(@yscale)] = $scale / 0x4000;
	  }else {
	    $xscale[scalar(@xscale)] = 1.0;
	    $yscale[scalar(@yscale)] = 1.0;
	    $scale10[scalar(@scale10)] = 0.0;
	    $scale01[scalar(@scale01)] = 0.0;
}
	    
	    

	$count++;
	
} while($flags & $MORE_COMPONENTS);
    
#print "x translate:", "@xtranslate", "\n";
#print "Y translate:". "@ytranslate", "\n";
for(my $i = 0; $i < $count; $i++){
      #print "Glyph: ", $glyph_index[$i], "\n";
      #print "****", "$xtranslate[$i]", "\n";
      #print "****", "$ytranslate[$i]", "\n";
  if ( ! defined $xscale[$i]){ $xscale[$i] = 1.0 ; }
  if ( ! defined $yscale[$i]){ $yscale[$i] = 1.0 ; }
  if ( ! defined $scale10[$i]){ $scale10[$i] = 0.0 ; }
  if ( ! defined $scale01[$i]){ $scale01[$i] = 0.0 ; }
    	my @param  = get_simple_glyph_coord($glyph_index[$i]);
	if ( $param[0]){ 
	my @scaled = scale(@param, $xscale[$i], $yscale[$i], $scale10[$i], $scale01[$i]);
	#print "****", "$xtranslate[2]", "\n";
      #print "*****xtranslate:$xtranslate[$i]\n";
	#print "*****ytranslate:$ytranslate[$i]\n";
	my @translated = translate(@scaled, $xtranslate[$i], $ytranslate[$i]);
	$s .= get_path_as_svg(@translated);
       # print "$s\n\n";
      }
      }
return $s;
}

sub mid_value { 
  my $x = shift; 
  my $y = shift;

  #print $x, " *  ", $y, "\n";
  #Batik rounds off all the coordinates
  #There is no proper rounding way in perl except floor and ceiling
  # Here is the logic- if the fraction is >= 0.5 take the ceiling otherwise
  # take the floor

  my $value =  ($x+$y)/2;
  #my $int_value = int($value);
  #my $delta = $value - $int_value;

  #return ($delta >=0.5)? ceil($value) : floor($value);
  return ceil($value);
}

sub scale {
  my @x = @{shift @_};
  my @y = @{shift @_};
  my $on_path = shift;
  my $end_points = shift;
  my $xscale = shift;
  my $yscale = shift;
  my $scale10 = shift;
  my $scale01 = shift;
  my @scaled_x;
  my @scaled_y;
  
  for (my $i  = 0; $i < @x ; $i++){
    $scaled_x[$i] = int( $x[$i] * $xscale + $y[$i] * $scale10);
    $scaled_y[$i] = int( $x[$i] * $scale01 + $y[$i] * $yscale);
  }
  return ( \@scaled_x, \@scaled_y, $on_path, $end_points);
} 

#sub scale_y {
#  my $x = shift;
#  my $y = shift;
#  my $yscale = shift;
#  my $scale01 = shift;

#  return int( ($x * $scale01) + ($y * $yscale) );
#} 

sub translate {
  my @x = @{shift @_};
  my @y = @{shift @_};
  my $on_path = shift;
  my $end_points = shift;
  my $x_translate = shift;
my $y_translate = shift;
  my @trans_x;
  my @trans_y;

  for ( my $i =0 ; $i < @x; $i++){
    $trans_x[$i] = $x[$i] + $x_translate;
    $trans_y[$i] = $y[$i] + $y_translate;
  }
return ( \@trans_x, \@trans_y, $on_path, $end_points);
}

#sub get_units_per_em {
#    my $buf;
#    seek(INFILE, $table{"head"}, 0);
#    read(INFILE, $buf, 54) == 54 || die "reading head table";
#    my($units_per_em) = unpack("x18n", $buf);
#    return $units_per_em;
#}

sub get_index_to_loca_format {
    my $buf;
    seek(INFILE, $table{"head"}, 0);
    read(INFILE, $buf, 54) == 54 || die "reading head table";
    my($index_to_loca_format) = unpack("x50n", $buf);
    return $index_to_loca_format;
}

sub maxp_get_number_of_glyph {
    my $buf;
    seek(INFILE, $table{"maxp"}, 0);
    read(INFILE, $buf, 6);
    my ($num_glyph) = unpack("x4n", $buf);
    return $num_glyph;

}

sub loca_get_glyph_location {
    my $index = shift;
    my $buf;
    my $glyph_location;
    my  $index_to_loc = get_index_to_loca_format($index);
    my $num_glyph = maxp_get_number_of_glyph();
    my $type = "short";
    my (@loca);
    my $num = $num_glyph +1;
    #print "NUM : $num\n";
    if ($index_to_loc == 1){
       $type = "long";
    }
    seek(INFILE, $table{"loca"}, 0);
    if ($type eq "short"){
       read(INFILE, $buf, 2 * $num);
       @loca = unpack("n"x $num, $buf);
       $glyph_location = $loca[$index] * 2;
    }
    else{
       read(INFILE, $buf, 4 * $num);
       @loca = unpack("N$num", $buf);
       $glyph_location= $loca[$index];
    }
    return $glyph_location;
}

sub write_kern_data {
 my ($l, $r, $k) = @_;
 my $s = "<hkern g1=\"".get_glyph_name($l)."\" g2=\"".get_glyph_name($r)."\" k=\"$k\" />\n";
 return $s;
}

sub make_ps_name_table {
  my $buf;
  seek(INFILE, $table{"post"}, 0);
  read(INFILE, $buf, 4);
  my $format_type = unpack("N", $buf);
  #print "Format type:$format_type\n";
  
  if ( $format_type == 131072 ){ # Test whether 0x00020000
    #print "Microsoft table! \n";
    read(INFILE, $buf, 30);
    my $num_glyphs = unpack("x28n", $buf);
    #print $num_glyphs, "\n";
    my $highest_glyph_index = 0;
    
    for ( my $i = 0; $i < $num_glyphs; $i++){
      read(INFILE, $buf, 2);
      $glyph_name_index[$i] = unpack("n", $buf);
      if($highest_glyph_index < $glyph_name_index[$i]){
	$highest_glyph_index = $glyph_name_index[$i];
      }
    }
  
    if($highest_glyph_index > 257){
      $highest_glyph_index -= 257;
    }

    for( my $i = 0; $i < $highest_glyph_index; $i++){
      read(INFILE, $buf, 1);
      my $length = unpack("C",$buf);
      read(INFILE, $buf, $length);
      $post_glyph_name[$i] = pack("C*",unpack("C*", $buf));
      #print $post_glyph_name[$i], "\n";
    }
      
  } elsif ( $format_type == 131077){
    #Do Nothing
  }
}


sub make_mac_glyph_name{
 @mac_glyph_name = (  ".notdef","null", "CR", "space",
        "exclam",       # 4
        "quotedbl",     # 5
        "numbersign",   # 6
        "dollar",       # 7
        "percent",      # 8
        "ampersand",    # 9
        "quotesingle",  # 10
        "parenleft",    # 11
        "parenright",   # 12
        "asterisk",     # 13
        "plus",         # 14
        "comma",        # 15
        "hyphen",       # 16
        "period",       # 17
        "slash",        # 18
        "zero",         # 19
        "one",          # 20
        "two",          # 21
        "three",        # 22
        "four",         # 23
        "five",         # 24
        "six",          # 25
        "seven",        # 26
        "eight",        # 27
        "nine",         # 28
        "colon",        # 29
        "semicolon",    # 30
        "less",         # 31
        "equal",        # 32
        "greater",      # 33
        "question",     # 34
        "at",           # 35
        "A",            # 36
        "B",            # 37
        "C",            # 38
        "D",            # 39
        "E",            # 40
        "F",            # 41
        "G",            # 42
        "H",            # 43
        "I",            # 44
        "J",            # 45
        "K",            # 46
        "L",            # 47
        "M",            # 48
        "N",            # 49
        "O",            # 50
        "P",            # 51
        "Q",            # 52
        "R",            # 53
        "S",            # 54
        "T",            # 55
        "U",            # 56
        "V",            # 57
        "W",            # 58
        "X",            # 59
        "Y",            # 60
        "Z",            # 61
        "bracketleft",  # 62
        "backslash",    # 63
        "bracketright", # 64
        "asciicircum",  # 65
        "underscore",   # 66
        "grave",        # 67
        "a",            # 68
        "b",            # 69
        "c",            # 70
        "d",            # 71
        "e",            # 72
        "f",            # 73
        "g",            # 74
        "h",            # 75
        "i",            # 76
        "j",            # 77
        "k",            # 78
        "l",            # 79
        "m",            # 80
        "n",            # 81
        "o",            # 82
        "p",            # 83
        "q",            # 84
        "r",            # 85
        "s",            # 86
        "t",            # 87
        "u",            # 88
        "v",            # 89
        "w",            # 90
        "x",            # 91
        "y",            # 92
        "z",            # 93
        "braceleft",    # 94
        "bar",          # 95
        "braceright",   # 96
        "asciitilde",   # 97
        "Adieresis",    # 98
        "Aring",        # 99
        "Ccedilla",     # 100
        "Eacute",       # 101
        "Ntilde",       # 102
        "Odieresis",    # 103
        "Udieresis",    # 104
        "aacute",       # 105
        "agrave",       # 106
        "acircumflex",  # 107
        "adieresis",    # 108
        "atilde",       # 109
        "aring",        # 110
        "ccedilla",     # 111
        "eacute",       # 112
        "egrave",       # 113
        "ecircumflex",  # 114
        "edieresis",    # 115
        "iacute",       # 116
        "igrave",       # 117
        "icircumflex",  # 118
        "idieresis",    # 119
        "ntilde",       # 120
        "oacute",       # 121
        "ograve",       # 122
        "ocircumflex",  # 123
        "odieresis",    # 124
        "otilde",       # 125
        "uacute",       # 126
        "ugrave",       # 127
        "ucircumflex",  # 128
        "udieresis",    # 129
        "dagger",       # 130
        "degree",       # 131
        "cent",         # 132
        "sterling",     # 133
        "section",      # 134
        "bullet",       # 135
        "paragraph",    # 136
        "germandbls",   # 137
        "registered",   # 138
        "copyright",    # 139
        "trademark",    # 140
        "acute",        # 141
        "dieresis",     # 142
        "notequal",     # 143
        "AE",           # 144
        "Oslash",       # 145
        "infinity",     # 146
        "plusminus",    # 147
        "lessequal",    # 148
        "greaterequal", # 149
        "yen",          # 150
	"mu",           # 151
        "partialdiff",  # 152
        "summation",    # 153
        "product",      # 154
	"pi",           # 155
        "integral'",    # 156
        "ordfeminine",  # 157
        "ordmasculine", # 158
	"Omega",        # 159
        "ae",           # 160
        "oslash",       # 161
        "questiondown", # 162
        "exclamdown",   # 163
        "logicalnot",   # 164
        "radical",      # 165
        "florin",       # 166
        "approxequal",  # 167
        "increment",    # 168
        "guillemotleft",# 169
        "guillemotright",#170
        "ellipsis",     # 171
        "nbspace",      # 172
        "Agrave",       # 173
        "Atilde",       # 174
        "Otilde",       # 175
        "OE",           # 176
        "oe",           # 177
        "endash",       # 178
        "emdash",       # 179
        "quotedblleft", # 180
        "quotedblright",# 181
        "quoteleft",    # 182
        "quoteright",   # 183
        "divide",       # 184
        "lozenge",      # 185
        "ydieresis",    # 186
        "Ydieresis",    # 187
        "fraction",     # 188
        "currency",     # 189
        "guilsinglleft",# 190
        "guilsinglright",#191
        "fi",           # 192
        "fl",           # 193
        "daggerdbl",    # 194
        "middot",       # 195
        "quotesinglbase",#196
        "quotedblbase", # 197
        "perthousand",  # 198
        "Acircumflex",  # 199
        "Ecircumflex",  # 200
        "Aacute",       # 201
        "Edieresis",    # 202
        "Egrave",       # 203
        "Iacute",       # 204
        "Icircumflex",  # 205
        "Idieresis",    # 206
        "Igrave",       # 207
        "Oacute",       # 208
        "Ocircumflex",  # 209
        "",             # 210
        "Ograve",       # 211
        "Uacute",       # 212
        "Ucircumflex",  # 213
        "Ugrave",       # 214
        "dotlessi",     # 215
        "circumflex",   # 216
        "tilde",        # 217
        "overscore",    # 218
        "breve",        # 219
        "dotaccent",    # 220
        "ring",         # 221
        "cedilla",      # 222
        "hungarumlaut", # 223
        "ogonek",       # 224
        "caron",        # 225
        "Lslash",       # 226
        "lslash",       # 227
        "Scaron",       # 228
        "scaron",       # 229
        "Zcaron",       # 230
        "zcaron",       # 231
        "brokenbar",    # 232
        "Eth",          # 233
        "eth",          # 234
        "Yacute",       # 235
        "yacute",       # 236
        "Thorn",        # 237
        "thorn",        # 238
        "minus",        # 239
        "multiply",     # 240
        "onesuperior",  # 241
        "twosuperior",  # 242
        "threesuperior",# 243
        "onehalf",      # 244
        "onequarter",   # 245
        "threequarters",# 246
        "franc",        # 247
        "Gbreve",       # 248
        "gbreve",       # 249
        "Idot",         # 250
        "Scedilla",     # 251
        "scedilla",     # 252
        "Cacute",       # 253
        "cacute",       # 254
        "Ccaron",       # 255
        "ccaron",       # 256
        ""              # 257
    );
}
sub get_glyph_name {
  my $index = shift;
  if( $glyph_name_index[$index] > 257){
    #print $post_glyph_name[$glyph_name_index[$index] -258], "******\n";
    return $post_glyph_name[$glyph_name_index[$index] -258];
  } else {
    #print $glyph_name_index[$index], "*****\n";
    #print $mac_glyph_name[$glyph_name_index[$index]], "******\n";
    #print $mac_glyph_name[3], "*****\n";
    return $mac_glyph_name[$glyph_name_index[$index]];
}
}

sub process_kern_table {
  my $buf;
  my $s = "";
  seek (INFILE, $table{"kern"} , 0);
  read (INFILE, $buf, 4);
  my $num_of_tables = unpack("x2n", $buf);
  #print $num_of_tables, "\n";

  for (my $i = 0; $i < $num_of_tables; $i++){
    read ( INFILE, $buf, 4);
    my $length = unpack("x2n", $buf);
    read ( INFILE, $buf, 2);
    my $coverage = unpack("n", $buf);
    my $format = $coverage >> 8;
    #print $format, "\n";
    
    if ( ($format == 0) && (($coverage & 1) != 0)){
      #print "FORMAT 0\n";
      read (INFILE, $buf, 2);
      my $npairs = unpack("n", $buf);
      #print $npairs, "\n";
      read(INFILE, $buf, 6);
      
      for ( my $j = 0; $j < $npairs; $j++){
	read(INFILE, $buf, 4);
	# my $right_and_left = unpack("N", $buf);
	my ( $left, $right) = unpack("nn", $buf);
	read(INFILE, $buf, 2);
	my $kern_data = unpack("n", $buf);
	$kern_data = $kern_data - ($kern_data > 32768 ? 65536 : 0);
	$kern_data = $kern_data * ( -1);
	if(exists($kern_to_print{$left})){
	  $s .= write_kern_data($left, $right, $kern_data);
	}
	  
	#print get_glyph_name($left), ":", get_glyph_name($right);
	#print "$right_and_left ";

#	$kern{$right_and_left} = $kern_data;
	#print $kern_data, "\n";
	
      }
     } else {
       read ( INFILE, $buf, $length -6);
}
}
return $s; 
}
sub print_instructions {
   print "\nTruetype v1.0 to SVG converter - v0.04, April 2, 2002.\n";
   print 'Copyright (c) 2002 Malay <curiouser@gene.ccmbindia.org>', "\n";
   print "You can do whatever you want to do with this program with the same condition as Perl itself. Just don't blame me for anything!\n\n";
   print "Usage: \nPastel-ttf2svg.pl -f <ttffile> [-l NNN] [-h NNN] [-i CCC] [-t] [-s]\n";
   print "      -f <ttffile>    - The full path name of the TTF file\n";
   print "      -l NNN          - The low index number of the character. Default 32.\n";
   print "      -h NNN          - The high index number of the character. Default 255.\n";
   print "      -i CCC          - Font id.\n";
   print "      -t              - Print a SVG file with the glyphs displayed\n";
   print "      -s              - This is Symbol font file.\n";
   print "                        Default characters parsed is from 61472 to 61695.\n";
   print "                        When using your own high and low character values\n"; 
   print "                        use character numbers between 61472 to 61695.\n";    
print "\nThis program only parses Microsoft table of the font.\n";  
}

sub print_test {
  my $s = "";
  $s .= '<g style="font-family:'.get_font_family().';font-size:32;fill:black">';
#if($ENCODING_ID == 1){
#$s .= '<text x="20" y="60"> !&quot;#$%&amp;&apos;()*+,-./0123456789:;&lt;&gt;?</text>';
#$s .= '<text x="20" y="120">@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_</text>';
#$s .= '<text x="20" y="180">`abcdefghijklmnopqrstuvwxyz|{}~</text>';

##$s .= '<text x="20" y="240">&#x80;&#x81;&#x82;&#x83;&#x84;&#x85;&#x86;&#x87;&#x88;&#x89;&#x8a;&#x8b;&#x8c;&#x8d;&#x8e;&#x8f;&#x90;&#x91;&#x92;&#x93;&#x94;&#x95;&#x96;&#x97;&#x98;&#x99;&#x9a;&#x9b;&#x9c;&#x9d;&#x9e;&#x9f;</text>';

#$s .='<text x="20" y="300">&#xa0;&#xa1;&#xa2;&#xa3;&#xa4;&#xa5;&#xa6;&#xa7;&#xa8;&#xa9;&#xaa;&#xab;&#xac;&#xad;&#xae;&#xaf;&#xb0;&#xb1;&#xb2;&#xb3;&#xb4;&#xb5;&#xb6;&#xb7;&#xb8;&#xb9;&#xba;&#xbb;&#xbc;&#xbd;&#xbe;&#xbf;</text><text x="20" y="360">&#xc0;&#xc1;&#xc2;&#xc3;&#xc4;&#xc5;&#xc6;&#xc7;&#xc8;&#xc9;&#xca;&#xcb;&#xcc;&#xcd;&#xce;&#xcf;&#xd0;&#xd1;&#xd2;&#xd3;&#xd4;&#xd5;&#xd6;&#xd7;&#xd8;&#xd9;&#xda;&#xdb;&#xdc;&#xdd;&#xde;&#xdf;</text><text x="20" y="420">&#xe0;&#xe1;&#xe2;&#xe3;&#xe4;&#xe5;&#xe6;&#xe7;&#xe8;&#xe9;&#xea;&#xeb;&#xec;&#xed;&#xee;&#xef;&#xf0;&#xf1;&#xf2;&#xf3;&#xf4;&#xf5;&#xf6;&#xf7;&#xf8;&#xf9;&#xfa;&#xfb;&#xfc;&#xfd;&#xfe;&#xff;</text></g>';


#}

#if($ENCODING_ID == 0 ){
    my $counter = 0;
    my $y = 60;
    $s .= "<text x=\"20\" y=\"$y\">";       
    
    for (my $i = 0 ; $i < @TEST_GLYPHS; $i++){
         
if($counter == 31){
             $y += 60;
             $s .= "</text>\n<text x=\"20\" y=\"".$y."\">";
             $counter  = 0;
         }
         $s .= $TEST_GLYPHS[$i];
$counter++;   
}
  $s .= '</text><text x = "20" y="550"> A quick brown fox jumps over the lazy dog</text>';
 $s .= '<text x="20" y="610">Kerning: Va Wa V, </text>';
    $s .= "</g>";
 # }
return $s;
}

__END__

=head1 NAME

B<Pastel-ttf2svg.pl version 0.04> 

- a true type font to Scalable Vector Graphics 
font converter. Distrubuted along with Pastel tookit but can be used
as a stand-alone perl script.

=head1 SYNOPSIS

  Pastel-ttf2svg.pl -f <TTF file> [-l NNN] [-h NNN] [-i CCC]  [-t] [-s] 
 
  -f <ttffile>    - The full path name of the TTF file
  -l NNN          - The low index number of the character. Default 32.
  -h NNN          - The high index number of the character. Default 255
  -i CCC          - Font id.
  -t              - Print a SVG file with the glyphs displayed
  -s              - This is Symbol font file. Default characters
                    parsed is from 61472 to 61695. When using your
                    own high and low character values use character 
                    numbers between 61472 to 61695.

=head1 DESCRIPTION

Patel-ttf2svg.pl is a Perl script that parses a True Type Font file and generates a SVG font file which can be used to display a SVG file in platform independant manner. Till date the only program that allows to do it is Batik toolkit from apache. It is advisable to generate the font only with the glyph that is required for a given document.

=head1 OPTIONS

  -f <ttffile> - The full path name of the TTF font file. This is required. 
                 Ofcourse!!!

  -l NNN       - The lower character number to parse. The ascii character
                 sets starts with the character 32 which is default for 
                 the program.

  -h NNN       - The highest character number to parse. The program default
                 is 255. Please note that some of the glyphs that are required
                 in a given SVG file may be beyond this range. In that case use
                 the highest glyph number for the character sets.

  -i CCC       - The font id. Required for referencing the font inside an SVG
                 file.

  -t           - Just a boolean parameter. When passed outputs a complete SVG
                 file with the glyhs created to test a particular font.

  -s           - A boolean flag required for using Microsoft non standard fonts
                 like Wingding, Marlett etc. If you just supply this argument
                 without the -l and -h options then it set the "low character"
                 to 61472 and the high character to 61695. When you want to
                 supply your own low and high characters please specify it 
                 within this range. To see the complete lists of glyphs use
                 pastel-ttf2svg.pl -f mywinding.ttf -t -s


=head1 AUTHOR

Malay Kumar Basu, curiouser@gene.ccmbindia.org

=cut
