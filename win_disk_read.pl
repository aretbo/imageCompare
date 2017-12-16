#!/usr/local/bin/perl
use English;
use strict;
use IO::File;
use Compress::Zlib;
use Win32;
use Win32API::File 0.08 qw( :ALL );
use Time::HiRes;
 
my $os_handle = "";
my $data      = "";
my $offset    = 0;
my $length    = -1000;
my $status    = 0;
my $i;
my $tick_counter;
my $last_tick_counter;
my $ltr               = 512;
my $offset_low        = 0;
my $offset_high       = 0;
my $offset_high_print = 0;
my $real_offset;
my $from_where           = FILE_CURRENT;
my $empty_blocks_counter = 0;
my $calculate_offset     = 0;
my $silent               = 0;
my $compressed           = "";
my $compressed_length    = 0;
my $reduction            = 0;
my $total_length         = 0;
my $pattern              = "_NOT_SET_";
my $report_empty_blocks  = 1;
my $start_time           = Time::HiRes::time();
my $read_time;
my $total_read_time = 0.0;
 
sub _printf
{
    if ( $silent != 1 )
    {
        printf( $ARG[0] );
    }
}
 
sub _print_hex
{
    my $i          = "";
    my $counter    = 0;
    my $text       = "";
    my $compressed = "";
    my $input      = $ARG[0];
    my $length     = 0;
    my $block      = $ARG[1];
    my @list       = "";
 
    #    printf("-"x65 . "0123456789ABCDEF\n");
    @list = split( '', $input );
    if (    $pattern ne "_NOT_SET_"
        and $input =~ m/$pattern/ )
    {
        printf( "# pattern [$pattern] seen in block [$block] "
              . ord( $list[-1] )
              . ord( $list[-2] )
              . "\n" );
    }
    if ( $silent == 0 )
    {
        if ( $input =~ m/[\00]{512,512}/ )
        {
            $empty_blocks_counter = $empty_blocks_counter + 1;
            if ( $report_empty_blocks == 1 )
            {
                printf("# All bytes 00 in block [$block]\n");
            }
        }
        else
        {
            foreach $i ( split( '', $input ) )
            {
                printf( "%02X", ord($i) );
                $counter = $counter + 1;
                if (    $counter > 0
                    and $counter % 4 == 0 )
                {
                    printf(" ");
                }
                if (    ord($i) >= 32
                    and ord($i) <= 126
                    and ord($i) != 94
                    and ord($i) != 95 )
                {
                    $text = $text . $i;
                }
                else
                {
                    $text = $text . " ";
                }
                if ( $counter == 32 )
                {
                    printf(" $text \n");
                    $text    = "";
                    $counter = 0;
                }
            }
        }
    }
}
 
sub read_mbr_win
{
    my $blocks = 1;
    my $time;
 
    if ( defined( $ARGV[0] ) )
    {
        $blocks = int( $ARGV[0] );
    }
    if ( defined( $ARGV[1] ) )
    {
        $ltr = 512 * int( $ARGV[1] );
    }
    if ( defined( $ARGV[2] ) )
    {
        $offset = 512 * int( $ARGV[2] );
        printf( "# OFFSET entered [" . $offset . "]\n" );
    }
    if ( defined( $ARGV[3] ) )
    {
        if ( $ARGV[3] eq "B" )
        {
            $from_where = FILE_BEGIN;
        }
        if ( $ARGV[3] eq "E" )
        {
            $from_where = FILE_END;
        }
        printf( "# FROM [" . $from_where . "]\n" );
    }
    if ( defined( $ARGV[4] ) )
    {
        if ( $ARGV[4] eq "S" )
        {
            $silent = 1;
        }
        if ( $ARGV[4] eq "Q" )
        {
            $silent = 1;
        }
    }
    if ( defined( $ARGV[5] ) )
    {
        $pattern             = $ARGV[5];
        $report_empty_blocks = 0;
    }
    $calculate_offset = 0;
    if ( $offset > ( 2**32 - 1 ) )
    {
        $offset_high       = int( $offset / 2**32 );
        $offset_high_print = $offset_high;
        $offset_low        = $offset % 2**32;
        $calculate_offset  = 1;
 
        #        $offset_low = 2**32 - $offset_low + 1;
    }
    else
    {
        $offset_high       = [];
        $offset_high_print = 0;
        $offset_low        = $offset;
    }
    printf( "# OFFSET [" . $offset_high_print . " " . $offset_low . "]\n" );
 
    #    $handle = Win32API::File::createFile("\\\\?", "?");
    #    $os_handle = Win32API::File::createFile("\\\\.\\PhysicalDrive0",'r');
    $os_handle = Win32API::File::createFile( "//./PhysicalDrive0", 'r' );
    printf( "# HANDLE [" . $os_handle . "]\n" );
    printf( "# EXTENDED_OS_ERROR createFile [" . $EXTENDED_OS_ERROR . "]\n" );
    printf( "# fileLastError createFile ["
          . Win32API::File::fileLastError()
          . "]\n" );
    $real_offset =
      Win32API::File::SetFilePointer( $os_handle, $offset_low, $offset_high,
        $from_where );
    printf(
        "# EXTENDED_OS_ERROR SetFilePointer [" . $EXTENDED_OS_ERROR . "]\n" );
    printf( "# fileLastError SetFilePointer ["
          . Win32API::File::fileLastError()
          . "]\n" );
    $real_offset = $real_offset / 512;
 
    if ($calculate_offset)
    {
        $real_offset = $real_offset + ( $offset_high * 2**32 ) / 512;
    }
    printf( "# real_offset SetFilePointer [" . $real_offset . "]\n" );
    printf( "# OFFSET [" . $offset_high_print . " " . $offset_low . "]\n" );
    foreach $i ( 1 .. $blocks )
    {
        $last_tick_counter = Win32::GetTickCount();
        $read_time =  Time::HiRes::time();
        $status = Win32API::File::ReadFile( $os_handle, $data, $ltr, $length, [] );
 
        $total_read_time = $total_read_time + Time::HiRes::time() - $read_time;
 
        $tick_counter = Win32::GetTickCount();
        $tick_counter = $tick_counter - $last_tick_counter;
 
 
 
#       _printf("# status of ReadFile [" . int($status) . "]\n");
#       _printf("# fileLastError after ReadFile [" . Win32API::File::fileLastError() . "]\n");
#       _printf("# received length [". int($length) . "] \n");
        _printf("# block ["
              . ( $real_offset + int( $i - 1 ) )
              . "] BEGIN $tick_counter\n" );
 
        #       _printf("# read data with ReadFile is :\n");
        _print_hex( $data, ( $real_offset + int( $i - 1 ) ) );
        if ( $silent == 1 )
        {
            $compressed = $data;
        }
        else
        {
#            $compressed = compress($data);
            $compressed = $data;
        }
        $compressed_length = length($compressed);
        $reduction         = $reduction + ( $length - $compressed_length );
        $total_length      = $total_length + $length;
        _printf("# block ["
              . ( $real_offset + int( $i - 1 ) )
              . "] END   $tick_counter $compressed_length $reduction $total_length\n"
        );
    }
    Win32API::File::CloseHandle($os_handle);
    printf( "# blocks [" . $blocks . "] \n" );
    printf( "# empty blocks [" . $empty_blocks_counter . "] \n" );
    printf( "# reduction [" . ( $reduction / $total_length ) * 100 . "] \n" );
    printf( "# total length [" . $total_length . "] \n" );
    $time = ( Time::HiRes::time() - $start_time );
    printf("# total elapsed time [$time] seconds\n" );
    if ($time > 0.0 )
    {
        printf( "# data processing rate ["
          . ($total_length / $time)
          . "] bytes per second\n" );
    }   
}
read_mbr_win();
