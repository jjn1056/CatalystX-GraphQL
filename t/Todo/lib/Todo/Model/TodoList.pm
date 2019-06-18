package Todo::Model::TodoList;

use Moose;
extends 'Catalyst::Model';

has data => (
  is => 'rw',
  required => 1,
  default => sub {
    return [
      {task => 'Exercise!'},
      {task => 'Bulk Milk'},
      {task => 'Walk Dogs'},
    ];
  }
);

sub todos {
  my ($self, $args, $context) = @_;
  return $self->data;
}

sub add_todo {
  my ($self, $args) = @_;
  $self->data([
    @{$self->todos},
    $args
  ]);
  return $args;
}

1;
