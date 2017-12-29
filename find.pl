#!/usr/bin/perl

use URI::Escape;
use Encode 'decode_utf8';

$qs = $ENV{QUERY_STRING};
if (!$qs)
{
    $qs = $ARGV[0];
}

sub Main
{
    %query = ();
    foreach my $item (split(/&/, $qs))
    {
        my ($name,$value) = split(/=/, $item);
        $value =~ s/\+/ /g;
        $value = uri_unescape ($value);
        $value = decode_utf8 ($value);
        $query{$name} = $value;
    }
    if ($query{"movie"})
    {
        Movie($query{"movie"});
    }
    elsif ($query{"actor"})
    {
        Actor($query{"actor"});
    }
    else
    {
        print "Status: 400 Bad query - no movie or actor\r\n";
        print "Content-Type: text/plain\r\n\r\n";
        print "No movie or actor found in query.\r\n";
    }
}

sub Movie
{
    my ($title) = @_;
    $title =~ s/\$/\\\$/g;
    $titlefile = $title;
    $titlefile =~ s|/|%2F|g;
    $filename = "movie/$titlefile";
    unless (-f $filename)
    {
        CacheMovie($title, $filename);
    }
    open(MOVIE, $filename);
    while (<MOVIE>)
    {
        print;
    }
    close(MOVIE);
}

sub CacheMovie
{
    my ($title, $filename) = @_;
    open(MOVIE, ">$filename");
    my $movie = `gzip -cd title.movies.tsv.gz | grep "\t$title\t" | head -1`;
    if (!$movie)
    {
        print MOVIE "Status: 404 Movie not found\n";
        print MOVIE "Content-Type: text/plain\r\n\r\n";
        print MOVIE "Movie not found: $title\n";
        exit
    }
    print MOVIE "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
    chop $movie;
    my ($tid) = split(/\t/, $movie);
    my $cast = `gzip -cd title.principals.tsv.gz | grep $tid | head -1`;
    if (!$cast)
    {
        $cast = "$tid   \\N\n";
    }
    chop $cast;
    my ($t,$castList) = split(/\t/, $cast);
    print MOVIE "$movie ";
    my $count = 0;
    foreach my $nid (split(/,/, $castList))
    {
        my $name = `grep $nid name.actors.tsv | head -1`;
        if ($name)
        {
            if ($count++)
            {       
                print MOVIE ",";
            }
            ($n, $actor) = split(/\t/, $name);
            print MOVIE $actor;
        }
    }
    print MOVIE "\n";
    close(MOVIE);
}

sub Actor
{
    my ($name) = @_;
    $actorfile = $name;
    $actorfile =~ s|/|%2F|g;
    $filename = "actor/$actorfile";
    unless (-f $filename)
    {
        CacheActor($name, $filename);
    }
    open(ACTOR, $filename);
    while (<ACTOR>)
    {
        print;
    }
    close(ACTOR);
}

sub CacheActor
{
    my ($name, $filename) = @_;
    open(ACTOR, ">$filename");
    my $actor = `grep "$name" name.actors.tsv | head -1`;
    if (!$actor)
    {
        print ACTOR "Status: 404 Actor not found\n";
        print ACTOR "Content-Type: text/plain\n\n";
        print ACTOR "Actor not found: $actor\n";
        exit;
    }
    print ACTOR "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
    chop $actor;
    my ($nid, $name, $bd, $dd, $pp, $knownForTitles) = split(/\t/, $actor);
    print ACTOR $nid, "\t", $name, "\t", $bd, "\t", $dd, "\t", $pp, "\t";
    my $count = 0;
    foreach my $tid (split(/,/, $knownForTitles))
    {
        my $title = `gzip -cd title.movies.tsv.gz | grep $tid | head -1`;
        if ($title)
        {
            if ($count++)
            {
                print ACTOR ",";
            }
            ($t, $type, $movie) = split(/\t/, $title);
            print ACTOR $movie;
        }
    }
    print ACTOR "\n";
    close(ACTOR);
}

Main();

