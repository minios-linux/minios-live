#!/usr/bin/perl
# SPDX-License-Identifier: GPL-2.0+
#
# iBFT ACPI table generator
# $ perldoc ibft.pl if you'd like to read the manual, poor you:

=head1 NAME

ibft.pl - Generate iBFT ACPI table

=head1 SYNOPSIS

ibft.pl
[--oemid <oemid>]
[--tableid <tableid>
[--initiator isns=<ip>,slp=<ip>,radius1=<ip>,radius2=<ip>,iqn=<iqn>]
[--nic ip=<ip>[,prefix=<prefix>][,gw=<ip>][,dns1=<ip>][,dns2=<ip>][,dhcp=<ip>][,vlan=<id>][,mac=<mac>][,pci=<pci>][,hostname=<hostname>] ...]
[--target ip=<ip>[,port=<port>][,lun=<lun>][,name=<iqn> ...]

=head1 DESCRIPTION

B<ibft.pl> creates an image of iBFT ACPI table similar to what a real network
boot firmware would do. This is mainly useful for testing.

=head1 OPTIONS

=over 4

=item B<< --oemid <oemid> >>

Create a table with a particular OEM ID, limited to 6 characters.
It generally doesn't matter.

Defaults to I<DRACUT>.

=item B<< --tableid <tableid> >>

Create a table with a particular OEM Table ID.

Defaults to I<TEST>, but any four-letter word would do. Any.

=item B<< --initiator >>

Configure the Initiator Structure.
Following parameters are supported:

=over 4

=item B<< isns=<ip> >>

iSNS server address.

=item B<< slp=<ip> >>

SLP server address.

=item B<< radius1=<ip> >>, B<< radius2=<ip> >>

Primary and secondary Radius server addresses.

=item B<< iqn=<iqn> >>

Override the IQN, which defaults to I<iqn.2009-06.dracut:initiator0>.

=back

=item B<< --nic >>

Configure a NIC Structure. This option can be used up multiple times.

Following parameters are supported:

=over 4

=item B<< ip=<ip> >>

Set the IP address. Both I<AF_INET> and I<AF_INET6> families are supported.
This parameter is mandatory.

=item B<< prefix=<prefix> >>

Set the IP address prefix. You generally also want to set this in order to
get a sensible iBFT.

=item B<< gw=<ip> >>

Set the gateway IP address.

=item B<< dns1=<ip> >>, B<< dns2=<ip> >>

Set the domain service server addresses.

=item B<< dhcp=<ip> >>

Specify the address of the DHCP server in case dynamic configuration is used.

=item B<< vlan=<id> >>

The VLAN Id. Duh.

=item B<< mac=<mac> >>

Specify the ethernet hardware address, in form of six colon-delimited
hexadecimal octets.

=item B<< pci=<pci> >>

Specify the ethernet hardware's PCI bus location, in form of
B<< <bus> >>:B<< <device> >>.B<< <function> >> where the numbers are in
hexadecimal.

=item B<< hostname=<hostname> >>

The host name. Defaults to B<client>.

=back

=item B<< --target >>

Configure a Target Structure. This option can be used multiple times.

Following parameters are supported:

=over 4

=item B<< ip=<ip> >>

The iSCSI target IP address.

=item B<< port=<port> >>

The iSCSI TCP port, in case the default of I<3260> is not good enough for
you.

=item B<< lun=<1> >>

The LUN number. Defaults to I<1> no less.

=item B<< name=<iqn> >>

The iSCSI volume name. Defaults to I<iqn.2009-06.dracut:target0> for the first
target, I<iqn.2009-06.dracut:target1> for the second one.

=back

=back

=cut

use strict;
use warnings;

sub ip4 {
	shift =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/
		or die 'not an INET address';
	return (map { 0x00 } 0..9), 0xff, 0xff, $1, $2, $3, $4;
}

sub ip6
{
	my ($beg, $end) = map { [ map { /^([0-9a-fA-F]{0,2}?)([0-9a-fA-F]{1,2})$/
		? (hex $1, hex $2)
		: die "'$_' not valid in a INET6 address"
	} split /:/ ] } split /::/, shift;

	$beg ||= [];
	$end ||= [];

	my $fill = 16 - scalar @$beg + scalar@$end;
	die 'INET6 address too long' if $fill < 0;

	@$beg, (map { 0 } 1..$fill), @$end;
}

sub ip
{
	my @val;
	@val = eval { @val = ip6 ($_[0]) };
	@val = eval { @val = ip4 ($_[0]) } unless @val;
	die "Saatana: $_[0] is not an INET or INET6 address" unless @val;

	return pack 'C16', @val;
}

sub mac
{
	return pack 'C8', map { hex $_ } split /:/, shift;
}

sub pci
{
	shift =~ /^([0-9a-fA-F]{1,2}?):([0-9a-fA-F]{1,2})\.([0-9a-fA-F]+)$/
		or die 'Not a PCI address';
	return (hex $1) << 8 | (hex $2) << 3 | (hex $3);
}

sub lun
{
	return pack 'C8', 0, shift, 0, 0, 0, 0, 0, 0;
}

# signature, length, revision, checksum, oem_id, oem_table_id, reserved
sub pack_table_hdr { pack 'a4 V C C a6 a8 a24  x![C8]', @_ }

# id, version, length, index, flags
# extensions, initiator_off, nic0_off, tgt0_off, nic1_off, tgt1_off, ext*
sub pack_control { pack 'C C S C C  S  S  S S  S S  S*  x![C8]', @_ }

# id, version, length, index, flags
# isns_adr, slp_adr, radius1_adr, radius2_adr, iqn_len, iqn_off
sub pack_initiator { pack 'C C S C C  a16 a16 a16 a16 SS  x![C8]', @_ }

# id, version, length, index, flags
# adr, prefix, origin, gw, dns1, dns2, dhcp, vlan_id, mac, pci_bdf, hostname_len, hostname_off
sub pack_nic { $_[5] ? pack 'C C S C C  a16 C C a16 a16 a16 a16 S a6 S SS  x![C8]', @_ : '' }

# id, version, length, index, flags
# tgt_adr, tgt_port, tgt_lun, chap_type, nic_id, tgt_len, tgt_off,
# chap_name_len, chap_name_off, chap_secret_len, chap_secret_off
# rchap_name_len, rchap_name_off, rchap_secret_len, rchap_secret_off
sub pack_tgt { $_[5] ? pack 'C C S C C  a16 S a8 C C SS SS SS SS SS  x![C8]', @_ : '' };

# str
sub pack_str { pack 'Z*', @_ }

# Initialize some defaults
my @table_hdr = ('iBFT', 0000, 1, 0000, 'DRACUT', 'TEST', '');
my @control = (1, 1, 18, 0, 0, 0000, 0000, 0000, 0000, 0000, 0000);
my @initiator = (2, 1, 74, 0, 0x03, '', '', '', '', (0000, 0000));
my @nics;
my @tgts;
my $iqn = 'iqn.2009-06.dracut:initiator0';
my @hostnames;
my @tgt_names;

while (@ARGV) {
	my $arg = shift @ARGV;
	die "Saatana: $arg is missing an argument" unless @ARGV;

	if ($arg eq '--oemid') {
		$table_hdr[4] = shift @ARGV;
	} elsif ($arg eq '--tableid') {
		$table_hdr[5] = shift @ARGV;
	} elsif ($arg eq '--initiator') {
		my %val = split /[,=]/, shift @ARGV;
		$initiator[5] = ip (delete $val{isns}) if exists $val{isns};
		$initiator[6] = ip (delete $val{slp}) if exists $val{slp};
		$initiator[7] = ip (delete $val{radius1}) if exists $val{radius1};
		$initiator[8] = ip (delete $val{radius2}) if exists $val{radius2};
		$iqn = delete $val{iqn} if exists $val{iqn};
		die "Saatana: Extra arguments to --initiator: ".join (', ', %val) if %val;
	} elsif ($arg eq '--nic') {
		my @nic = (3, 1, 102, 0, 0x03,
			undef, 0, 0x01, '', '', '', '', 0, '', 0, (0000, 0000));
		push @nics, \@nic;

		my %val = split /[,=]/, shift @ARGV;
		die 'Saatana: --nic needs an ip' unless exists $val{ip};
		$nic[3] = $#nics;
		$nic[5] = ip (delete $val{ip});
		$nic[6] = delete $val{prefix} if exists $val{prefix};
		$nic[7] = 0x03 if exists $val{dhcp};
		$nic[8] = ip (delete $val{gw}) if exists $val{gw};
		$nic[9] = ip (delete $val{dns1}) if exists $val{dns1};
		$nic[10] = ip (delete $val{dns2}) if exists $val{dns2};
		$nic[11] = ip (delete $val{dhcp}) if exists $val{dhcp};
		$nic[12] = delete $val{vlan} if exists $val{vlan};
		$nic[13] = mac (delete $val{mac}) if exists $val{mac};
		$nic[14] = pci (delete $val{pci}) if exists $val{pci};
		$hostnames[$#nics] = exists $val{hostname} ? delete $val{hostname} : 'client';
		$hostnames[$#nics] = pack_str $hostnames[$#nics];
		die "Saatana: Extra arguments to --nic: ".join (', ', %val) if %val;

		# Allocate an control expansion entry
		if ($#nics > 1) {
			$control[2] += 2;
			push @control, (0x4444);
		}
	} elsif ($arg eq '--target') {
		my @tgt = (4, 1, 54, 0, 0x03,
			undef, 3260, lun (1), 0, 0,
			(0000, 0000),
			(0000, 0000),
			(0000, 0000),
			(0000, 0000),
			(0000, 0000));
		push @tgts, \@tgt;

		my %val = split /[,=]/, shift @ARGV;
		die 'Saatana: --target needs an ip' unless exists $val{ip};
		$tgt[3] = $#tgts;
		$tgt[5] = ip (delete $val{ip}) if exists $val{ip};
		$tgt[6] = delete $val{port} if exists $val{port};
		$tgt[7] = lun (delete $val{lun}) if exists $val{lun};
		$tgt[9] = delete $val{nic} if exists $val{nic};
		$tgt_names[$#tgts] = exists $val{name} ? delete $val{name}
			: 'iqn.2009-06.dracut:target'.$#tgts;
		$tgt_names[$#tgts] = pack_str $tgt_names[$#tgts];
		die "Saatana: Extra arguments to --target: ".join (', ', %val) if %val;

		# Allocate an control expansion entry if necessary
		if ($#tgts > 1) {
			$control[2] += 2;
			push @control, (0x1111);
		}
	} else {
		die "Saatana: Unknown argument: $arg";
	}
}

# Pass 1
my $table_hdr = pack_table_hdr @table_hdr;
my $control = pack_control @control;
my $initiator = pack_initiator @initiator;
my @packed_nics = map { pack_nic @$_ } @nics;
my @packed_tgts = map { pack_tgt @$_ } @tgts;
$iqn = pack_str $iqn;


# Resolve the offsets
my $len = 0;
$len += length $table_hdr;
$len += length $control;
$control[6] = $len;
$len += length $initiator;

for my $i (0..$#packed_nics) {
	if ($i == 0) {
		# NIC 0
		$control[7] = $len;
	} elsif ($i == 1) {
		# NIC 1
		$control[9] = $len;
	} else {
		# Expansion
		$control[11 + $i - 2] = $len;
	}
	$len += length $packed_nics[$i];
}

for my $i (0..$#packed_tgts) {
	if ($i == 0) {
		# Target 0
		$control[8] = $len;
	} elsif ($i == 1) {
		# Target 1
		$control[10] = $len;
	} else {
		# Expansion
		$control[11 + scalar @packed_nics - 2 + $i - 2] = $len;
	}
	$len += length $packed_tgts[$i];
}

$initiator[9] = -1 + length $iqn;
$initiator[10] = $len;
$len += length $iqn;

for my $i (0..$#hostnames) {
	$nics[$i]->[15] = -1 + length $hostnames[$i];
	$nics[$i]->[16] = $len;
	$len += length $hostnames[$i];
}

for my $i (0..$#tgt_names) {
	$tgts[$i]->[10] = -1 + length $tgt_names[$i];
	$tgts[$i]->[11] = $len;
	$len += length $tgt_names[$i];
}

@table_hdr[1] = $len;

# Pass 2, with the offsets resolved
$table_hdr = pack_table_hdr @table_hdr;
$control = pack_control @control;
$initiator = pack_initiator @initiator;
@packed_nics = map { pack_nic @$_ } @nics;
@packed_tgts = map { pack_tgt @$_ } @tgts;

# Pass 3, calculate checksum
my $cksum = 0xff;
$cksum += ord $_ foreach split //, join '', $table_hdr, $control, $initiator,
	@packed_nics, @packed_tgts, $iqn, @hostnames, @tgt_names;
$cksum = ~$cksum & 0xff;
$table_hdr[3] = $cksum;
$table_hdr = pack_table_hdr @table_hdr;

# Puke stuff out
print $table_hdr;
print $control;
print $initiator;
print @packed_nics;
print @packed_tgts;
print $iqn;
print @hostnames;
print @tgt_names;

=head1 EXAMPLES

=over

=item B<< perl ibft.pl --oemid FENSYS --tableid iPXE --nic ip=192.168.50.101,prefix=24,gw=192.168.50.1,dns1=192.168.50.1,dhcp=192.168.50.1,vlan=0,mac=52:54:00:12:34:00,pci=00:02.0,hostname=iscsi-1 --target ip=192.168.50.1 >ibft.img >>

Generate an iBFT image with a single NIC while pretending we're iPXE for
no good reason.

=item B<<perl ibft.pl --initiator iqn=iqn.1994-05.com.redhat:633114aacf2 --nic ip=192.168.50.101,prefix=24,gw=192.168.50.1,dns1=192.168.50.1,dhcp=192.168.50.1,mac=52:54:00:12:34:00,pci=00:03.0 --nic ip=192.168.51.101,prefix=24,gw=192.168.51.1,dns1=192.168.51.1,dhcp=192.168.51.1,mac=52:54:00:12:34:01,pci=00:04.0 --target ip=192.168.50.1,port=3260,lun=1,name=iqn.2009-06.dracut:target0 --target ip=192.168.51.1,port=3260,lun=2,name=iqn.2009-06.dracut:target1 >ibft.img >>

Generate an iBFT image for two NICs while being slightly more expressive
than necessary.

=item B<qemy-system-x86_64 -acpitable file=ibft.img>

Use the image with QEMU.

=back

=head1 BUGS

No support for CHAP secrets.

=head1 SEE ALSO

=over 4

=item L<qemu(1)>,

=item L<iSCSI Boot Firmware Table (iBFT)|ftp://ftp.software.ibm.com/systems/support/bladecenter/iscsi_boot_firmware_table_v1.03.pdf>,

=item L<NL_PREFIX_ORIGIN Enumeration|https://docs.microsoft.com/en-us/windows/win32/api/nldef/ne-nldef-nl_prefix_origin>

=back

=head1 COPYRIGHT

Copyright (C) 2019 Lubomir Rintel

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 AUTHOR

Lubomir Rintel C<lkundrak@v3.sk>

=cut

# Forgive me.
# This would have been much easier with FORTH.
