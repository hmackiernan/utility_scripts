sub ask_from_list {
    my ($question, @answers) = @_;
    my $size = scalar(@answers);
    while (1) {
        print "$question?\n";
        for (my $i = 0 ; $i < $size ; $i++) {
            print "$i : $answers[$i]\n";
        }
        my $result = <STDIN>;
        chomp($result);
        return ($answers[$result]) if ($result >= 0 && $size >= $result);
    }
}

sub ask {
    my ($question, $accept_blank) = @_;

    while (1) {
        print $question . "\n";
        my $result = <STDIN>;
        chomp($result);
        return $result if (length($result) || $accept_blank);
    }
}

sub ask_long {
    my ($question) = @_;
    while (1) {
        print $question . "\n";
        print "(when you are finished typing your answer, type '.'\n";
        my $text;
        while (1) {
            my $line = <STDIN>;
            chomp($line);
            if ($line =~ /^\.$/) {
                if (length($text)) {
                    return ($text);
                } else {
                    last;
                }
            }
            $text .= $line;
        }
    }
}
