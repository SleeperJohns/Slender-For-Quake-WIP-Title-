#!/usr/bin/perl
# fgd2def.pl - builds a Radiant style .def from a TrenchBroom .fgd
#
# usage: perl fgd2def.pl Slender.fgd Slender.def
#
# The .fgd is the only source. Base classes are flattened into every entity,
# keys and choices become description text, and model() is kept in the
# TrenchBroom { model(...); } block. Output uses CRLF like the rest of the repo.

use strict;
use warnings;

my ($in, $out) = @ARGV;
die "usage: perl fgd2def.pl input.fgd output.def\n" unless defined $in && defined $out;

open my $fh, '<:raw', $in or die "$in: $!\n";
my $src = do { local $/; <$fh> };
close $fh;
$src =~ s/\r//g;

my $pos = 0;
my $len = length $src;

sub fail {
    my $line = 1 + (substr($src, 0, $pos) =~ tr/\n//);
    die "$in:$line: $_[0]\n";
}

# whitespace and // comments
sub ws {
    while ($pos < $len) {
        my $c = substr($src, $pos, 1);
        if ($c =~ /\s/) { $pos++; next; }
        if (substr($src, $pos, 2) eq '//') {
            my $e = index($src, "\n", $pos);
            $pos = $e < 0 ? $len : $e;
            next;
        }
        last;
    }
}

sub peek { ws(); return $pos < $len ? substr($src, $pos, 1) : ''; }

sub expect {
    my $c = shift;
    fail("expected '$c'") unless peek() eq $c;
    $pos++;
}

sub word {
    ws();
    pos($src) = $pos;
    fail('expected a name or number') unless $src =~ /\G([A-Za-z0-9_.\-]+)/gc;
    $pos = pos($src);
    return $1;
}

sub str {
    ws();
    fail('expected a string') unless substr($src, $pos, 1) eq '"';
    my $e = index($src, '"', $pos + 1);
    fail('unterminated string') if $e < 0;
    my $s = substr($src, $pos + 1, $e - $pos - 1);
    $pos = $e + 1;
    return $s;
}

sub value { return peek() eq '"' ? str() : word(); }

# raw text between ( and its matching ), strings may hold parentheses
sub balanced {
    expect('(');
    my $start = $pos;
    my $depth = 1;
    while ($pos < $len) {
        my $c = substr($src, $pos, 1);
        if ($c eq '"') {
            my $e = index($src, '"', $pos + 1);
            fail('unterminated string') if $e < 0;
            $pos = $e + 1;
            next;
        }
        $depth++ if $c eq '(';
        if ($c eq ')' && --$depth == 0) {
            my $s = substr($src, $start, $pos - $start);
            $pos++;
            return $s;
        }
        $pos++;
    }
    fail('unbalanced parenthesis');
}

# ": desc : default : long description", any of them may be missing
sub fields {
    my @f;
    while (peek() eq ':') {
        $pos++;
        my $c = peek();
        if ($c eq ':' || $c eq '=' || $c eq ']') { push @f, undef; next; }
        push @f, value();
    }
    return @f;
}

sub props {
    my @p;
    expect('[');
    while (peek() ne ']') {
        fail('unexpected end of file') if $pos >= $len;
        my $name = word();
        expect('(');
        my $type = lc word();
        expect(')');
        my ($desc, $def, $long) = fields();
        my @opts;
        if (peek() eq '=') {
            $pos++;
            expect('[');
            while (peek() ne ']') {
                fail('unexpected end of file') if $pos >= $len;
                my $v = value();
                my ($od, $odef, $olong) = fields();
                push @opts, { value => $v, desc => $od // '', long => $olong };
            }
            expect(']');
        }
        push @p, { name => $name, type => $type, desc => $desc // '', def => $def,
                   long => $long, opts => \@opts };
    }
    expect(']');
    return \@p;
}

my (%classes, @order);
while (peek() ne '') {
    expect('@');
    my $kind = lc word();
    my %attr;
    while (peek() ne '=') {
        fail('unexpected end of file') if $pos >= $len;
        my $a = lc word();
        $attr{$a} = balanced();
    }
    $pos++;
    my $name = word();
    my $desc = '';
    if (peek() eq ':') { $pos++; $desc = str(); }
    my $props = peek() eq '[' ? props() : [];
    fail("duplicate class $name") if $classes{$name};
    $classes{$name} = { kind => $kind, attr => \%attr, desc => $desc, props => $props };
    push @order, $name;
}

# own attributes win over base ones, the first base wins among bases
# a key redefined later replaces the earlier one, spawnflags are merged by bit
sub resolve {
    my ($name, $seen) = @_;
    my $c = $classes{$name} or die "$in: unknown base class '$name'\n";
    return $c->{flat} if $c->{flat};
    die "$in: base class loop at '$name'\n" if $seen->{$name}++;

    my (%attr, @props, %idx);
    my $add = sub {
        for my $p (@{ $_[0] }) {
            if (!exists $idx{ $p->{name} }) {
                $idx{ $p->{name} } = @props;
                push @props, $p;
                next;
            }
            my $old = $props[ $idx{ $p->{name} } ];
            if ($p->{type} eq 'flags' && $old->{type} eq 'flags') {
                my %o = map { $_->{value} => $_ } @{ $old->{opts} }, @{ $p->{opts} };
                $props[ $idx{ $p->{name} } ] =
                    { %$p, opts => [ map { $o{$_} } sort { $a <=> $b } keys %o ] };
            } else {
                $props[ $idx{ $p->{name} } ] = $p;
            }
        }
    };

    for my $b (split /,/, $c->{attr}{base} // '') {
        $b =~ s/^\s+|\s+$//g;
        next unless length $b;
        my $f = resolve($b, $seen);
        for my $k (keys %{ $f->{attr} }) { $attr{$k} //= $f->{attr}{$k}; }
        $add->($f->{props});
    }
    for my $k (keys %{ $c->{attr} }) { $attr{$k} = $c->{attr}{$k} unless $k eq 'base'; }
    $add->($c->{props});

    $c->{flat} = { attr => \%attr, props => \@props };
    return $c->{flat};
}

# color(255 128 0) -> 1 0.5 0
sub color {
    my $c = shift;
    return undef unless defined $c;
    return join ' ', map {
        my $x = sprintf('%.2f', $_ / 255);
        $x =~ s/0+$//;
        $x =~ s/\.$//;
        $x;
    } split ' ', $c;
}

# size(mins, maxs), a single vector is centered on the origin
sub bbox {
    my $s = shift;
    return '(-8 -8 -8) (8 8 8)' unless defined $s;
    my @parts = split /,/, $s;
    my @a = split ' ', $parts[0];
    if (@parts > 1) {
        my @b = split ' ', $parts[1];
        return "(@a) (@b)";
    }
    my @mn = map { -$_ / 2 } @a;
    my @mx = map { $_ / 2 } @a;
    return "(@mn) (@mx)";
}

# "Crusher (no reverse)" -> CRUSHER_NO_REVERSE
sub flagname {
    my $n = uc shift;
    $n =~ s/'//g;
    $n =~ s/[^A-Z0-9]+/_/g;
    $n =~ s/^_+|_+$//g;
    return length $n ? $n : 'FLAG';
}

sub isbit { my $v = shift; return $v =~ /^\d+$/ && $v > 0 && ($v & ($v - 1)) == 0; }

sub sentence {
    my $s = shift;
    $s =~ s/\s+$//;
    return $s =~ /[.!?:]$/ ? $s : "$s.";
}

(my $inname = $in) =~ s{.*[/\\]}{};
(my $outname = $out) =~ s{.*[/\\]}{};

my @lines = (
    "// Slender entity definition file (.def)",
    "// Generated from $inname by fgd2def.pl. Do not edit by hand:",
    "// edit $inname and run: perl fgd2def.pl $inname $outname",
    '',
);
my $count = 0;

for my $name (@order) {
    my $c = $classes{$name};
    next if $c->{kind} eq 'baseclass';
    my $f = resolve($name, {});
    my $solid = $c->{kind} eq 'solidclass';
    my ($flags) = grep { $_->{type} eq 'flags' } @{ $f->{props} };

    # flag names go by bit position, gaps become -
    my @tok;
    if ($flags) {
        for my $o (@{ $flags->{opts} }) {
            next unless isbit($o->{value});
            my $bit = 0;
            $bit++ while (1 << $bit) < $o->{value};
            $tok[$bit] = flagname($o->{desc});
        }
    }

    my $rgb = color($f->{attr}{color}) // '0 0.5 0.8';
    my $hdr = "/*QUAKED $name ($rgb) " . ($solid ? '?' : bbox($f->{attr}{size}));
    $hdr .= ' ' . join(' ', map { $_ // '-' } @tok) if @tok;
    push @lines, $hdr;

    if (defined $f->{attr}{model}) {
        (my $m = $f->{attr}{model}) =~ s/\s+/ /g;
        $m =~ s/^ | $//g;
        push @lines, '{', "model($m);", '}';
    }

    my $desc = length $c->{desc} ? $c->{desc} : $name;
    push @lines, map { s/\s+$//r } split /\n/, $desc;

    my @keys = grep { $_->{type} ne 'flags' } @{ $f->{props} };
    if (@keys) {
        push @lines, '', '-------- KEYS --------';
        for my $k (@keys) {
            my $l = qq("$k->{name}" ) . sentence(length $k->{desc} ? $k->{desc} : $k->{name});
            if (defined $k->{def} && length $k->{def}) {
                my $d = $k->{def};
                my ($o) = grep { $_->{value} eq $d } @{ $k->{opts} };
                $d .= " ($o->{desc})" if $o;
                $l .= " Default: $d.";
            }
            push @lines, $l;
            push @lines, sentence($k->{long}) if defined $k->{long} && length $k->{long};
            push @lines, map { "  $_->{value} = $_->{desc}" } @{ $k->{opts} };
        }
    }

    if ($flags && @{ $flags->{opts} }) {
        push @lines, '', '-------- SPAWNFLAGS --------';
        for my $o (@{ $flags->{opts} }) {
            my $t = isbit($o->{value}) ? flagname($o->{desc}) . " ($o->{value})" : 'no flag';
            my $l = "$t : $o->{desc}";
            $l = sentence($l) . " $o->{long}" if defined $o->{long} && length $o->{long};
            push @lines, $l;
        }
    }

    push @lines, '*/', '';
    $count++;
}

my $text = join("\r\n", @lines) . "\r\n";
die "$in: a description contains */, which would close the .def comment\n"
    if ($text =~ s{/\*QUAKED}{}gr =~ s{\*/\r\n}{}gr) =~ m{\*/};

open my $oh, '>:raw', $out or die "$out: $!\n";
print $oh $text;
close $oh;
print "$outname: $count entities\n";
