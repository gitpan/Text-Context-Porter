package Text::Context::Porter;
use base 'Text::Context';
use strict;
use warnings;
use Lingua::Stem::En;

our $VERSION = "1.0";

=head1 NAME

Text::Context::Porter - Text::Context with inflection awareness

=head1 SYNOPSIS

  use Text::Context::Porter;

  my $snippet = Text::Context::Porter->new($text, @keywords);

  $snippet->keywords("foo", "bar"); # In case you change your mind

  print $snippet->as_html;
  print $snippet->as_text;

=head1 DESCRIPTION

Given a piece of text and some search terms, produces an object
which locates the search terms in the message, extracts a reasonable-length
string containing all the search terms, and optionally dumps the string out
as HTML text with the search terms highlighted in bold.

However, unlike the ordinary C<Text::Context>, this subclass is able to
highlight terms in the document which are inflected variants of the search
terms. For instance, searching for "testing" should highlight "test", 
"tested" and so on.

=cut

sub keywords {
    my ($self, @keywords) = @_;
    if (@keywords) {
        $self->{keywords} =  Lingua::Stem::En::stem({ -words => 
            [ map {s/\s+/ /g; lc $_} @keywords ]
        });
    }
    return @{$self->{keywords}};
}

sub para_class {"Text::Context::Para::Porter"}

sub paras {
    my $self = shift;
    my $max_len = shift || 80;
    $self->prepare_text;
    $self->score_para($_) for @{$self->{text_a}};
    my @paras = $self->get_appropriate_paras;
}

sub score_para {
    my ($self, $para) = @_;
    my $content = $para->{content};
    $content = join " ", @{Lingua::Stem::En::stem({ -words => [ split /\W+/, $para->{content} ] })};
    my %matches;
    # Do all the matching of keywords in advance of the boring
    # permutation bit
    for my $word (@{$self->{keywords}}) {
        my $word_score = 0;
        $word_score += 1 + ($content =~ tr/ / /) if $content =~ /\b\Q$word\E\b/i;
        $matches{$word} = $word_score;
    }
    #XXX : Possible optimization: Give up if there are no matches
    
    for my $wordset ($self->permute_keywords) { 
        my $this_score = 0;
        $this_score += $matches{$_} for @$wordset;
        $para->{scoretable}[$this_score] = $wordset if $this_score > @$wordset;
    }
    $para->{final_score} = $#{$para->{scoretable}};
}

package Text::Context::Para::Porter;
use constant DEFAULT_START_TAG => '<span class="quoted">';
use constant DEFAULT_END_TAG   => "</span>";
use base 'Text::Context::Para';
use HTML::Entities;

sub marked_up { 
    my $self      = shift;
    my $start_tag = shift || DEFAULT_START_TAG;
    my $end_tag   = shift || DEFAULT_END_TAG;
    my $content   = $self->as_text;
    my %words     = map {$_ => 1} @{$self->{marked_words}};
    my $output;
    for my $word (split /(\s+)/, $content) {
        if ($word =~ /\S/) {
            my ($stemmed) = @{Lingua::Stem::En::stem({ -words => [ $word ]})};
            if ($words{$stemmed}) {
               $word = $start_tag . encode_entities($word) . $end_tag;
            } else {
               $word = encode_entities($word);
            }
        }
        $output .= $word;
    }
    return $output;
}

=head1 COPYRIGHT

  Copyright (C) 2004 Simon Cozens

You may use and redistribute this module under the same terms as Perl
itself.

=cut

1;
