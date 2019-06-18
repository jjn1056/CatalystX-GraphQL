package Todo;

use Moose;
use Catalyst;

extends 'Catalyst';

__PACKAGE__->config(
  'Model::GraphQL' => {
      schema => __PACKAGE__->path_to("todo.graphql")->openr,
      root_value => +{ -model => 'TodoList' }, 
      graphiql => 1,
  },
);

__PACKAGE__->setup;
__PACKAGE__->meta->make_immutable;
