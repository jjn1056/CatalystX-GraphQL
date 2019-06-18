package Todo;

use Moose;
use Catalyst;

my $schema = q|
  type Todo {
    task: String!
  }

  type Query {
    todos: [Todo]
  }

  type Mutation {
    add_todo(task: String!): Todo
  }
|;

extends 'Catalyst';

__PACKAGE__->config(
  'Model::GraphQL' => {
      schema => $schema, 
      root_value => +{ -model => 'TodoList' }, 
      graphiql=>1,
  },
);

__PACKAGE__->setup;
__PACKAGE__->meta->make_immutable;
