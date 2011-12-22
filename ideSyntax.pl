#!/usr/bin/perl 
##  @file     ideSyntax.pl
#   @brief    Transform a tags file genereated by ctags ide format into a Syntax vim file
#   @details  Usage:
#              @verbatim  ideSyntax.pl [-h|--help] projectname @endverbatim
#   @note     All the properties and options are case insensitive.
#   @author   Daniel Gomez-Prado
#   @version  1.0
#   @date     09/09/2008 03:14:27 PM PDT

use strict;
use warnings;

use Shell qw(cat);
use File::Basename;
use Cwd qw(abs_path);
use Tie::File;

# hold the name of the current script file
my $what = $0;
my $root_dir = qx(pwd);	
if($root_dir=~m{^/cygdrive/([A-Za-z])/(.*)}){
	$root_dir = "$1:/$2";
}
if($root_dir=~m{(.*)\n}){
	$root_dir = "$1";
}

my $HELP = <<EOF
  Usage: 
	  $what
  Description:
	  $what transforms the IDE generated tags file for projectname into a vim syntax file
EOF
;

my $ide = "";
my $tagfile = "";
my $syntaxfile = "";
#chomp($currentDir);

# Start executing the script or show the help
if( @ARGV == 1 ){
	my $opt = $ARGV[0];
	if ($opt=~m/^--help$/ || $opt=~m/^-h$/) {
		print $HELP;
		exit 1;
	} else {
		$ide = $opt;
		$tagfile = "$opt.ide.tags";
		$syntaxfile = "$opt.ide.syntax"
	}
} else {
	print $HELP;
	exit 1;
}

#print "Entering main, with tagfile = $tagfile \n";
#print "Producing file, syntaxfile = $syntaxfile \n";
main();

sub get_priority {
	my $item;
	($item) = @_;
	if ($item=~m{class}){
		return 2;
	} elsif ($item=~m{member}){
		return 1;
	} else {
		return 0;
	}
}

sub check_priority {
	my $old;
	my $new;
	($old,$new) = @_;
	# CASE 1
	#   class has priority over prototypes/functions and members (etc)
	#   this resolves constructor/destructor re-coloring a class type
	# CASE 2
	#   member has priority over prototypes and functions (etc)
	#   this resolves multi-line constructor raw initialization 
	if ( get_priority($old) < get_priority($new) ) {
		#UPDATE necessary
		return 1;
	} else {
		return 0;
	}
}

sub main  {
	open INPUT, "< $tagfile" or die "Error: run ctags first\n";
	open OUTPUT, "> $syntaxfile" or die "ERROR: Can't open $syntaxfile for insertion, please check permissions\n";	
	my %syntax_table;
	while (<INPUT>) {
		my $current_item = $_;
		if( ($current_item=~m{^!.*}) || ($current_item=~m{^~.*}) || ($current_item=~m{^operator.*}) ) {
			# ignore tag comments, c++ destructors, operators
		} else {
			my $keyword = "";
			my $kind = "";
			my $access = "none";
			if( $current_item=~m{^([^\t]*)\t.*} ) {
				$keyword = $1;
			}
			if( $current_item=~m{.*\taccess:([^\t\n]*)\t.*$} ) {
				$access = $1;
			} elsif( $current_item=~m{.*\taccess:([^\t\n]*)$} ) { 
				$access = $1;
			}
			if( $current_item=~m{.*\tkind:([^\t\n]*)\t.*} ) {
				$kind = $1;
			} elsif( $current_item=~m{.*\tkind:([^\t\n]*)$} ) {
				$kind = $1;
			}
			if( !exists($syntax_table{$keyword}) || (exists($syntax_table{$keyword}) && check_priority($syntax_table{$keyword}{"kind"},$kind)) ) {
				$syntax_table{$keyword} = { 'kind' => $kind, 'access' => $access };
			}
			#print "$keyword | $kind == $syntax_table{$keyword}{'kind'} | $access == $syntax_table{$keyword}{'access'}\n";
		}
	}
	close INPUT;

	print OUTPUT "\" IDE syntax file for project $ide\n";
	print OUTPUT "\" Language   : C++ special highlighting for classes and methods\n";
	print OUTPUT "\" Author     : Daniel F. Gomez-Prado\n";
	print OUTPUT "\" Last Change: 2009 Oct 3\n";
	print OUTPUT "\n";
	print OUTPUT "if exists(\"b:current_syntax\")\n";
	print OUTPUT "\truntime! syntax/cpp.vim\n";
	print OUTPUT "\tunlet b:current_syntax\n";
	print OUTPUT "endif\n";
	print OUTPUT "\n";
	#my $count = 0;
	my @syntax_table_sorted = sort keys %syntax_table;
	my %group_table;
	foreach my $key (@syntax_table_sorted) {		
		my $group = "IDE_$ide"."_$syntax_table{$key}{'kind'}";
		if ( !($syntax_table{$key}{'access'} eq "none") ) {
			$group = "$group"."_$syntax_table{$key}{'access'}";
		}
		if( exists($group_table{$group}) ) { 
			$group_table{$group} = $group_table{$group}." ".$key;
		} else {
			$group_table{$group} = $key;
		}
		#print "$key | $syntax_table{$key}{'kind'} | $syntax_table{$key}{'access'}\n"; 
		#print "$group -> $key\n";
		#$count++;
	}
	my @group_table_sorted = sort keys %group_table;
	foreach my $atgroup (@group_table_sorted) {		
		print OUTPUT "syntax keyword $atgroup\t\t$group_table{$atgroup}\n";
		print OUTPUT "syntax cluster IDE_Cluster_$ide add=$atgroup\n"
		#print "$atgroup -> $group_table{$atgroup}\n";
	}
	print OUTPUT "\n";
	print OUTPUT "highlight default IDE_$ide"."None NONE\n";
	print OUTPUT "highlight default IDE_$ide"."TypeName cterm=bold term=bold gui=bold ctermfg=6 guifg=#40ffff\n"; #light blue
	print OUTPUT "highlight default IDE_$ide"."TypeNamePublic cterm=bold term=bold gui=bold ctermfg=6 guifg=#40ffff\n";
	print OUTPUT "highlight default IDE_$ide"."TypeNameProtected cterm=bold term=bold gui=bold ctermfg=6 guifg=#37dddd\n";
	print OUTPUT "highlight default IDE_$ide"."TypeNamePrivate cterm=bold term=bold gui=bold ctermfg=6 guifg=#2ebbbb\n";
	print OUTPUT "highlight default IDE_$ide"."Function cterm=bold term=bold gui=bold ctermfg=3 guifg=#ff6602\n"; #orange
	print OUTPUT "highlight default IDE_$ide"."FunctionPublic cterm=bold term=bold gui=bold ctermfg=3 guifg=#ff6602\n";
	print OUTPUT "highlight default IDE_$ide"."FunctionProtected cterm=bold term=bold gui=bold ctermfg=3 guifg=#d85601\n";
	print OUTPUT "highlight default IDE_$ide"."FunctionPrivate cterm=bold term=bold gui=bold ctermfg=3 guifg=#b24701\n";
	print OUTPUT "highlight default IDE_$ide"."Member cterm=bold term=bold gui=bold guifg=#159094 \n"; #cyan
	print OUTPUT "highlight default IDE_$ide"."MemberPublic cterm=bold term=bold gui=bold guifg=#159094 \n";
	print OUTPUT "highlight default IDE_$ide"."MemberProtected cterm=bold term=bold gui=bold guifg=#00868b \n";
	print OUTPUT "highlight default IDE_$ide"."MemberPrivate cterm=bold term=bold gui=bold guifg=#005255 \n";
	print OUTPUT "highlight default IDE_$ide"."Variable guifg=#7215a1 \n";
	print OUTPUT "highlight default IDE_$ide"."VariablePublic guifg=#7215a1 \n";
	print OUTPUT "highlight default IDE_$ide"."VariableProtected guifg=#660099 \n";
	print OUTPUT "highlight default IDE_$ide"."VariablePrivate guifg=#51007a \n";
	print OUTPUT "highlight default link IDE_$ide"."Constant PreProc\n";
	#print OUTPUT "highlight default IDE_$ide"."Constant cterm=bold term=bold gui=bold guifg=Magenta\n";
	print OUTPUT "\n";
	foreach my $atgroup (@group_table_sorted) {		
		print OUTPUT "highlight def link $atgroup \t IDE_$ide";
		my $item = "";
		my $type = "";
		if ($atgroup=~m{IDE_(.*)_(.*)_(.*)}) {
			$item = $2;
			$type = $3;
		} elsif ($atgroup=~m{IDE_(.*)_(.*)}) {
			$item = $2;
		}
		if (($item eq "class") || ($item eq "typedef") || ($item eq "enum") || ($item eq "struct") || ($item eq "namespace")) {
			print OUTPUT "Typename";
		} elsif (($item eq "prototype") || ($item eq "function")) {
			print OUTPUT "Function";
		} elsif ($item eq "variable") {
			print OUTPUT "Variable";
		} elsif ($item eq "member") {
			print OUTPUT "Member";
		} elsif (($item eq "macro") || ($item eq "enumerator")) {
			print OUTPUT "Constant";
		} else {
			print OUTPUT "None";
		}
		if ($type eq "private") {
			print OUTPUT "Private";
		} elsif ($type eq "protected") {
			print OUTPUT "Protected";
		} elsif ($type eq "public") {
			print OUTPUT "Public";
		}
		print OUTPUT "\n";
	}
	print OUTPUT "\n";
	print OUTPUT "let b:current_syntax = \"IDE_$ide\"\n";
	close OUTPUT;
	#print "There are $count elements\n"
}

