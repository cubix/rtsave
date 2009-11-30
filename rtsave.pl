#!/usr/bin/perl -w
#
# rtsave - Writes current Solaris routing table to shell script for boot.
#
#       Copyright 2003, Cubix
#
# Usage: rtsave [-f <filename> ] [-r <symlink> ] [-BFds]
# Options:
#       -f <filename>   - shell script that is created
#       -r <link>       - symlink used if -B is specified
#       -d              - do NOT save default (e.g. if defaultrouter file
#                       is used instead
#       -B              - creates new time-stamped file and updates symlink
#                       in rc2.d directory (or wherever specified)
#       -F              - force old file to be overwritten
#       -s              - create symlink (implied by -B)

#
# Constants you might want to change, but probably not
#
my $netstat_cmd = '/usr/bin/netstat -rvn';
my $route_cmd = '/usr/sbin/route';
my $defaultrouter = '/etc/defaultrouter';
my $perm = 0755;
my $hostmask = '255.255.255.255';

use Getopt::Std;
my %options;
my $opt = getopts('f:r:BFds', \%options);

#
# Paths here are defaults for output
#
my $config = defined($options{'f'}) ? 
  $options{'f'} : '/etc/init.d/routes';
my $rc_def = defined($options{'r'})
  ? $options{'r'} : '/etc/rc2.d/S70routes';

my $not_def = defined($options{'d'}) ? 1 : 0;
my $backup = defined($options{'B'}) ? 1 : 0;
my $force = defined($options{'F'}) ? 1 : 0;
my $sym = defined($options{'s'}) ? 1 : 0;

$config .= "." . file_name() if ($backup);

open(ROUTES, "$netstat_cmd |") or die "cannot execute: $netstat_cmd: $!";
open(CONF, ">$config") or die "cannot open config: $config: $!";
print CONF "#!/bin/sh\n";
print CONF "# Routing table - ", time_stamp(), "\n";

#
# Read routes from netstat cmd while writing shell script
#
while(<ROUTES>)
  {
    my ($dest, $netmask, $gateway, $inf) = split(/\s+/);
    next unless $dest =~ /^(?:\d{1,3}\.)|(?:def)/;
    # don't add local networks
    next if ($inf =~ /^[a-z]{2,3}\d{1,2}$/);
    #print "dest: $dest, mask: $netmask, gw: $gateway\n";
    if ($dest eq 'default')
      {
	next if ($not_def);
	open(DEF, ">$defaultrouter")
	  or die "cannot write defaultrouter: $defaultrouter: $!";
	print DEF $gateway;
	close(DEF);
      } 
    else
      {
	if ($netmask eq $hostmask)
	  {
	    print CONF "$route_cmd add -host $dest $gateway\n";
	  }
	else 
	  {
	    print CONF "$route_cmd add -net $dest -netmask $netmask $gateway\n";
	  }
      }
  }
close(CONF);
close(ROUTES);

#
# Creates/updates symblic link to active routes file. The previous one
# is not touched so that a recent change can be easily undone.
#
if (($sym || $backup) && $config ne $rc_def)
  {
    $force = 1 if (-l $rc_def);
    if (-e $rc_def||$force)
      {
	if (!($force))
	  {
	    print "File ($rc_def) exists, overwrite? (yes/no) ";
	    my $ans = <STDIN>;
	    die "file $rc_def exists and not symbolic link" unless $ans =~ m/^y/i;
	  }
	unlink($rc_def) or die "cannot delete symlink: $rc_def: $!";
      }
    $config = $ENV{'PWD'} . '/' . $config if !($config =~ /^\//);
    symlink($config, $rc_def) or die "cannot create symbolic link: $rc_def -> $config: $!";
  }
chmod($perm, $config) or warn "cannot chmod $config to $perm: $!";

sub time_stamp
{
  return(sprintf("%.4d/%.2d/%.2d %.2d:%.2d:%.2d", time_array()));
}

sub file_name
{
  return(sprintf("%.4d%.2d%.2d%.2d%.2d%.2d", time_array()));
}


sub time_array
{
  my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
  $mon++; $year += 1900;
  return ($year, $mon, $mday, $hour, $min, $sec);
}
