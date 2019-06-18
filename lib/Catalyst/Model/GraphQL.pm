package Catalyst::Model::GraphQL;

use Plack::Util;
use GraphQL::Execution;
use Safe::Isa;
use Moo;

extends 'Catalyst::Model';

has convert => (
  is => 'ro',
  isa => sub { ref($_[0]) ? 1:0 },
  predicate => 'has_convert',
  coerce => sub {
    if(ref($_[0]) eq 'ARRAY') {
      my ($class_proto, @args) = @{$_[0]};
      return normalize_convert_class($class_proto)->to_graphql(@args);
    } else {
      return $_[0]; # assume its a hashref already.
    }
  },
);

  sub normalize_convert_class {
    my $class_proto = shift;
    my $class = $class_proto =~m/^\+(.+)$/ ?
      $1 : "GraphQL::Plugin::Convert::$class_proto";
    return Plack::Util::load_class($class);
  }

has schema => (
  is => 'ro',
  isa => sub { ref($_[0]) ? 1:0 },
  lazy => 1,
  required => 1,
  builder => '_build_schema',
  coerce => sub {
    my $schema_proto = shift;
    return (  ref($schema_proto) =~m/GraphQL::Schema/) ?
      $schema_proto :
      coerce_schema($schema_proto);
  }
);

  sub coerce_schema {
    my $source = Plack::Util::is_real_fh($_[0]) ?
      do { local $/ = undef; <$_[0]> } : 
        $_[0];
    return Plack::Util::load_class("GraphQL::Schema")
      ->from_doc($source);
  }

  sub _build_schema {
    my $self = shift;
    return $self->has_convert ? 
      $self->convert->{schema} :
      undef;
  }

has root_value => (
  is => 'ro',
  required => 1,
  lazy => 1,
  builder => '_build_root_value',
);

  sub _build_root_value {
    my $self = shift;
    return $self->has_convert ? 
      $self->convert->{root_value} :
      undef;
  }

has resolver => (
  is => 'ro',
  required => 0,
  lazy => 1,
  builder => '_build_resolver',
);

  sub _build_resolver {
    my $self = shift;
    return $self->has_convert ? 
      $self->convert->{resolver} :
      undef;
  }

has promise_code => (
  is => 'ro',
  required => 0,
); # TODO waiting on GraphQL

has json_encoder => (
  is => 'ro',
  required => 1,
  handles => {
    json_encode => 'encode',
    json_decode => 'decode',
  },
  builder => '_build_json_encoder',
);

  our $DEFAULT_JSON_CLASS = 'JSON::MaybeXS';
  sub _build_json_encoder {
    return our $JSON_ENCODER ||= Plack::Util::load_class($DEFAULT_JSON_CLASS)
      ->new
      ->utf8
      ->allow_nonref;
  }

has graphiql => (
  is => 'ro',
  required => 1,
  builder => 'DEFAULT_GRAPHIQL',
);

  sub DEFAULT_GRAPHIQL { our $DEFAULT_GRAPHIQL ||= 0 }

has interactive_ui_class => (
  is => 'ro',
  required => 1,
  isa => sub { 1 },
  builder => 'DEFAULT_INTERACTIVE_UI_CLASS',
  coerce => sub { Plack::Util::load_class(shift) },
);

  sub DEFAULT_INTERACTIVE_UI_CLASS { our $DEFAULT_INTERACTIVE_CLASS ||= 'CatalystX::GraphQL::InteractiveUI' }

has interactive_ui => (
  is => 'ro',
  required => 1,
  init_arg => undef,
  builder => '_build_interactive_ui',
  lazy => 1,
);

  sub _build_interactive_ui {
    my $self = shift;
    $self->interactive_ui_class->new(json_encoder => $self->json_encoder);
  }

sub process {
  my ($self, $c) = @_;
  return $self->respond_graphiql($c) if $self->accepts_graphiql($c->req);
  return $self->respond_graphql($c) if $self->accepts_graphql($c->req);
  return $self->respond_415($c);

}

sub accepts_graphiql {
  my ($self, $req) = @_;
  return ($self->graphiql && $self->interactive_ui->accepts_request($req)) ? 1:0;
}

sub accepts_graphql {
  my ($self, $req) = @_;
  return (($req->env->{HTTP_ACCEPT}||'') =~ /^application\/json\b/) ? 1:0;
}

sub respond_graphiql {
  my ($self, $c) = @_;
  my $body = $self->interactive_ui->process($c->req);
  $c->res->status(200);
  $c->res->content_type('text/html');
  $c->res->body($body);
}

sub respond_415 {
  my ($self, $c) = @_;
  $c->status(415);
  $c->res->content_type('text/plain');
  $c->res->body('Unsupported Media Type');
}

sub respond_graphql {
  my ($self, $c) = @_;
  my $results = $self->prepare_results($c);
  my $body = $self->json_encode($results);
  $c->res->status(200);
  $c->res->content_type('application/json');
  $c->res->body($body);
}

sub prepare_results {
  my ($self, $c) = @_;
  my $data = $self->prepare_body($c);
  my $root_value = $self->prepare_root_value($c);
  my $results = $self->execute(
    $self->schema,
    $data,
    $root_value,
    $c,
    $self->resolver,
    $self->promise_code,
  );
  return $results;
}

sub prepare_body {
  my ($self, $c) = @_;
  return my $json_body = $c->req->body_data;
}

sub prepare_root_value {
  my ($self, $context) = @_;
  return my $root_value = (
    $context->stash->{graphql}{root_value}
    || $self->resolve_root_value_model($context)
    || $self->root_value);
}

sub resolve_root_value_model {
  my ($self, $context) = @_;
  if(
    (ref($self->root_value) eq 'HASH')
    and $self->root_value->{'-model'}
  ) {
    return my $model = $context->model($self->root_value->{'-model'});
  } else {
    return 0;
  }
}

sub execute {
  my ($self, $schema, $data, $root_value, $context, $resolver, $promise_code) = @_;
  return my $results = GraphQL::Execution::execute(
    $schema,
    $data->{query},
    $root_value,
    $context,
    $data->{variables},
    $data->{operationName},
    $resolver,
    $promise_code,
  );
}

1;

=head1 NAME
 
Catalyst::Model::GraphQL - Serve GraphQL from Catalyst

=begin markdown

# PROJECT STATUS

[![Build Status](https://travis-ci.org/jjn1056/Catalyst-Model-GraphQL.svg?branch=master)](https://travis-ci.org/jjn1056/Catalyst-Model-GraphQL)
[![CPAN version](https://badge.fury.io/pl/Catalyst-Model-GraphQL.svg)](https://metacpan.org/pod/Catalyst-Model-GraphQL) 

=end markdown
 
=head1 SYNOPSIS
 
    use Plack::App::GraphQL;

    my $schema = q|
      type Query {
        hello: String
      }
    |;

    my %root_value = (
      hello => 'Hello World!',
    );

    my $app = Plack::App::GraphQL
      ->new(schema => $schema, root_value => \%root_value)
      ->to_app;

=head1 DESCRIPTION
 
Serve L<GraphQL> with L<Catalyst>.

Please note this is an early access / minimal documentation release.  You should already
be familiar with L<GraphQL>.  There's some examples in C</examples> but few real test
cases.  If you are not comfortable using this based on reading the source code and
can't accept the possibility that the underlying code might change (although I expect
the configuration options are pretty set now) then you shouldn't use this. I recommend
looking at official plugins for Dancer and Mojolicious: L<Dancer2::Plugin::GraphQL>,
L<Mojolicious::Plugin::GraphQL> instead (or you can send me patches :) ).

This currently doesn't support an asychronous responses until updates are made in 
core L<GraphQL>.

This is API level documentation for this model, you should see L<CatalystX::GraphQL> for
how to set this up to run inside a L<Catalyst> application.

=head1 CONFIGURATION
 
This L<Catalyst::Model> applications supports the following configuration arguments:

=head2 schema

The L<GraphQL::Schema>.  Canonically this should be an instance of L<GraphQL::Schema>
but if you pass a string or a filehandle, we will assume that it is a parse-able 
graphql SDL document that we can build a schema object from.  Makes for easy demos.

=head2 root_value

An object, hashref or coderef that field resolvers can use to look up requests.  Generally
the method or hash keys will match the query or mutation keys.  See the examples for
more.

You can override this at runtime (with for example a bit of middleware) by using the
'plack.graphql.root_value' key in the PSGI $env.  This may or my not be considered a
good practice :)  Some examples suggest always using the $context for stuff like this
while other examples seem to think its a good idea.  I choose to rather enable this
ability and let you decide what is right for your application.

=head2 resolver

Used to change how field resolvers work.  See L<GraphQL> (or ignore this since its likely
something you really don't need for normal work.

=head2 convert

This takes a sub class of L<GraphQL::Plugin::Convert>, such as L<GraphQL::Plugin::Convert::DBIC>.
Providing this will automatically provide L</schema>, L</root_value> and L</resolver>.

You can shortcut the value of this with a '+' and we will assume the default namespace.  For
example '+DBIC' is the same as 'GraphQL::Plugin::Convert::DBIC'.

=head2 graphiql

Boolean that defaults to FALSE.  Turn this on to enable the HTML Interactive GraphQL query
screen.  Useful for leaning and debugging but you probably want it off in production.

B<NOTE> If you want to use this you should also install L<Template::Tiny> which is needed.  We
don't make L<Template::Tiny> a dependency here so that you are not forced to install it where
you don't want the interactive screens (such as production).

=head2 json_encoder

Lets you specify the instance of the class used for JSON encoding / decoding.  The default is an
instance of L<JSON::MaybeXS> so you will want to be sure install a fast JSON de/encoder in production,
such as L<Cpanel::JSON::XS> (it will default to a pure Perl one which might not need your speed 
requirements).

=head1 METHODS

    TBD
 
=head1 AUTHOR
 
John Napiorkowski <jnapiork@cpan.org>

=head1 SEE ALSO
 
L<GraphQL>, L<Catalyst>

=head1 COPYRIGHT

Copyright (c) 2019 by "AUTHOR" as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms as perl itself.
 
=cut

