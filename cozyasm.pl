#!/usr/bin/perl
use strict;
use Data::Printer;
use Getopt::Long;

my %INSN = (
    db  => ['db'],
    dw  => ['dw'],
    da  => ['da'],

    li  => ['li'],

    mov => ['xdsx', m => 0x6000, unary => 'nope'],
    or  => ['xdsx', m => 0x6001, unary => 'nope'],
    and => ['xdsx', m => 0x6002, unary => 'nope'],
    xor => ['xdsx', m => 0x6003, unary => 'nope'],
    shr => ['xdsx', m => 0x6004, unary => 'dd'],
    src => ['xdsx', m => 0x6005, unary => 'dd'],
    swp => ['xdsx', m => 0x6006, unary => 'dd'],
    not => ['xdsx', m => 0x6007, unary => 'dd'],
    add => ['xdsx', m => 0x6008, unary => 'nope'],
    adc => ['xdsx', m => 0x6009, unary => 'd0'],
    inc => ['xdsx', m => 0x600a, unary => 'dd'],
    dec => ['xdsx', m => 0x600b, unary => 'dd'],
    sub => ['xdsx', m => 0x600c, unary => 'nope'],
    sbc => ['xdsx', m => 0x600d, unary => 'd0'],
    neg => ['xdsx', m => 0x600e, unary => 'dd'],

    mfpc => ['xdsx', m => 0x5000, unary => 'd0', unary_only => 1],
    mtpc => ['xdsx', m => 0x5080, unary => 'd0', unary_only => 1],
    mflr => ['xdsx', m => 0x5001, unary => 'd0', unary_only => 1],
    mtlr => ['xdsx', m => 0x5081, unary => 'd0', unary_only => 1],

    halt => ['literal', op => 0x0000],

    ldb => ['mem', hi => 0x8, width => 1],
    ldw => ['mem', hi => 0x9, width => 2],
    ld  => ['mem', hi => 0x9, width => 2],
    stb => ['mem', hi => 0xa, width => 1],
    stw => ['mem', hi => 0xb, width => 2],
    st  => ['mem', hi => 0xb, width => 2],

    beq => ['br', cc => 0],
    bne => ['br', cc => 1],
    blt => ['br', cc => 2],
    bge => ['br', cc => 3],
    ble => ['br', cc => 4],
    bgt => ['br', cc => 5],
    bxx => ['br', cc => 6],
    bra => ['br', cc => 7],

    bleq => ['br', cc => 0, l => 1],
    blne => ['br', cc => 1, l => 1],
    bllt => ['br', cc => 2, l => 1],
    blge => ['br', cc => 3, l => 1],
    blle => ['br', cc => 4, l => 1],
    blgt => ['br', cc => 5, l => 1],
    blxx => ['br', cc => 6, l => 1],
    bl   => ['br', cc => 7, l => 1],

    nop => ['alias', args => 0, to => ['or', 'r0', 'r0']],
    clc => ['alias', args => 0, to => ['inc', 'r0', 'r0']],
    sec => ['alias', args => 0, to => ['dec', 'r0', 'r0']],
    b   => ['alias', args => 1, to => ['bra', '$1']],
);

my $ip = 0;
my @program;
my @program_source_lines;
my @constpool;
my @branch_fixups;
my %labels;

my $opt_output;
my $opt_list = 0;
my ($fh_hi, $fh_lo);

GetOptions(
    "output|o=s"    => \$opt_output,
    "list!"         => \$opt_list,
);

die "Need an output filename\n" if !defined $opt_output;
die "Output filename must end in .mem\n" if $opt_output !~ m{\.mem$};
$opt_output = substr $opt_output, 0, -4;
open $fh_hi, ">", "$opt_output.hi.mem" or die "$!";
open $fh_lo, ">", "$opt_output.lo.mem" or die "$!";

while (my $line = <>) {
    chomp $line;
    $line =~ s{(^|\s+);.*$}{}g;
    $line =~ s{^\s+|\s+$}{}g;
    next if !length $line;
    if ($line =~ m{^\.}) {
        my ($directive, @args) = split m{\s+}, $line;
        do_directive($directive, @args);
    } elsif ($line =~ m{:$}) {
        my $label = substr($line, 0, -1);
        die "Invalid label '$label'" if !valid_label($label);
        $labels{$label} = $ip;
    } else {
        my ($op, @args) = split m{(?:\s|,)\s*}, $line;
        do_instruction($op, @args);
    }
}

flush_constpool();

for my $fixup (@branch_fixups) {
    if (defined(my $target = $labels{$fixup->{target}})) {
        my $rel = ($target - 2) - $fixup->{source};
        die "wtf" if $rel & 1;
        die sprintf("Jump from %04x to %04x (%s) is out of range", $fixup->{source}, $target, $fixup->{target})
            if $rel > 512 or $rel < -512;
        $program[$fixup->{source}] |= ($rel >> 1) & 0x1ff;
    } else {
        die "Label '$fixup->{target}' never defined";
    }
}

if ($opt_list) {
    my $ellipsis = 0;
    for (my $p = 0; $p < @program; $p += 2) {
        if (defined $program[$p]) {
            print "<...>\n" if $ellipsis; $ellipsis = 0;
            printf "%04x: %04x  ; %s\n", $p, $program[$p], $program_source_lines[$p];
        } else {
            $ellipsis = 1;
        }
    }
}

for (my $p = 0; $p < @program; $p += 2) {
    my $op = $program[$p] // 0;
    printf $fh_hi "%02x\n", $op >> 8;
    printf $fh_lo "%02x\n", $op & 0xff;
}
close $fh_hi;
close $fh_lo;

##############################################################################

sub flush_constpool {
    # Deduplicate constants and gather all references for each
    my %const_refs;
    for my $c (@constpool) {
        push @{$const_refs{$c->{value}}}, $c->{source};
    }
    # Sort values by first occurrence
    my @sorted_consts = sort {
        $const_refs{$a}->[0] <=> $const_refs{$b}->[0]
    } keys %const_refs;
    for my $value (@sorted_consts) {
        $program[$ip] = $value;
        $program_source_lines[$ip] = sprintf("dw %04x ; constpool", $value);
        for my $source (@{$const_refs{$value}}) {
            my $offset = $ip - $source;
            die "Constant pool too far from its references" if $offset > 512;
            die "You need to flush constant pool before changing origin" if $offset <= 0;
            my $rel = ($offset - 2) / 2;
            die "wtf, rel=$rel\n" if $rel > 0xff;
            $program[$source] |= $rel;
            $program_source_lines[$source] .= sprintf(" - at %04x", $ip);
        }
        $ip += 2;
    }
    @constpool = ();
}

sub do_directive {
    my ($dir, @args) = @_;
    if ($dir eq ".org") {
        die "Wrong number of arguments to .org" if @args != 1;
        $ip = parse_number($args[0]);
        die "Refusing to set ip to an odd address" if $ip & 1;
    } elsif ($dir eq ".constpool") {
        flush_constpool();
    } else {
        die "Unknown directive '$dir'";
    }
}

sub do_instruction {
    my ($op, @args) = @_;
    my ($type, %prop) = @{$INSN{$op} or die "Unknown opcode '$op'"};
    my @insn;

    if ($type eq 'literal') {
        push @insn, $prop{op};

    } elsif ($type eq 'dw') {
        for my $dw (@args) {
            push @insn, parse_number($dw);
        }

    } elsif ($type eq 'db') {
        for (my $i = 0; $i < @args; $i += 2) {
            my ($lo, $hi) = ($args[$i], $args[$i+1]);
            push @insn, $hi << 8 | $lo;
        }

    } elsif ($type eq 'li') {
        die "Need register and value for $op" if @args != 2;
        my $r = parse_register($args[0]);
        die "Cannot load to r0" if $r == 0;
        my $v = parse_number($args[1]);

        my $op = ($r << 8);
        if ($v == ($v & 0x00ff)) { # 00xx
            push @insn, 0x0000 | $op | ($v & 0xff);
            push @args, "; 00xx";
        } elsif ($v == ($v | 0xff00)) { # ffxx
            push @insn, 0x1000 | $op | ($v & 0xff);
            push @args, "; ffxx";
        } elsif ($v == ($v & 0xff00)) { # xx00
            push @insn, 0x2000 | $op | (($v >> 8) & 0xff);
            push @args, "; xx00";
        } elsif ($v == ($v | 0x00ff)) { # xxff
            push @insn, 0x3000 | $op | (($v >> 8) & 0xff);
            push @args, "; xxff";
        } else {
            push @insn, 0x4000 | $op;
            push @constpool, { source => $ip, value => $v };
            push @args, "; pooled";
        }

    } elsif ($type eq 'mem') {
        die "Need register and register/offset" if @args != 2;
        my $rd = parse_register($args[0]);
        my ($n, $rs) = parse_register_offset($args[1]);
        if ($prop{width} == 2) {
            die "Cannot use odd offset with word-wide memory access" if $n & 1;
            $n >>= 1;
        }
        die "Offset too far" if $n > 15;
        push @insn, ($prop{hi} << 12) | ($rd << 8) | ($rs << 4) | $n;

    } elsif ($type eq 'xdsx') {
        die "Need arguments for $op" if @args < 1;
        die "Too many arguments for $op" if @args > ($prop{unary_only} ? 1 : 2);
        if (@args == 1) {
            if ($prop{unary} eq 'nope') {
                die "Need two arguments for $op";
            } elsif ($prop{unary} eq 'd0') {
                @args = ($args[0], 'r0');
            } elsif ($prop{unary} eq '0d') {
                @args = ('r0', $args[0]);
            } elsif ($prop{unary} eq 'dd') {
                @args = ($args[0], $args[0]);
            } else {
                die "Unknown unary for $op ??";
            }
        }
        my $rd = parse_register($args[0]);
        my $rs = parse_register($args[1]);
        push @insn, $prop{m} | ($rd << 8) | ($rs << 4);

    } elsif ($type eq 'br') {
        die "Need a label name for $op" if @args != 1 || !($args[0] eq '*' || valid_label($args[0]));
        push @insn, 0xc000 | ($prop{l} ? 0x1000 : 0) | ($prop{cc} << 9);
        push @branch_fixups, { source => $ip, target => $args[0] } if $args[0] ne '*';

    } elsif ($type eq 'alias') {
        die "Wrong number of arguments to $op" if @args != $prop{args};
        my @new = @{$prop{to}};
        s/^\$(\d+)$/$args[$1-1]/ for @new;
        do_instruction(@new);
        return;

    } else {
        die "unknown op type $type for $op ??";
    }

    $program_source_lines[$ip] = @args ? "$op @args" : $op if @insn;
    for my $i (@insn) {
        die sprintf("Program collision at %04x", $ip) if defined $program[$ip];
        die sprintf("Program out of bounds at %04x", $ip) if $ip > 0xffff;
        die sprintf("Program counter misaligned at %04x", $ip) if $ip & 1;
        $program[$ip] = $i;
        $ip += 2;
    }
}

sub parse_number {
    my ($n) = @_;
    $n =~ s/_//g;
    if ($n =~ m{^#[0-9]+$}) {
        return int substr($n, 1);
    } elsif ($n =~ m{^[0-9a-f]+$}i) {
        return hex($n);
    } else {
        die "Invalid number '$n'\n";
    }
}

sub parse_register {
    my ($r) = @_;
    if (my ($n) = $r =~ m{^r(\d+)$}) {
        return $n if $n < 16;
    }
    die "Invalid register '$r'";
}

sub parse_register_offset {
    my ($ra) = @_;
    if (my ($r) = $ra =~ m{^(r\d+)$}) {
        return (0, parse_register($r));
    } elsif (my ($n, $r) = $ra =~ m{^(\d+)\((r\d+)\)$}) {
        die "Invalid offset in '$ra'" if $n < 0;
        return (int $n, parse_register($r));
    } else {
        die "Invalid memory address '$ra'";
    }
}

sub valid_label {
    my ($lbl) = @_;
    return $lbl =~ m{^\w+$};
}
