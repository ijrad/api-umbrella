import Form from './form';

export default Form.extend({
  model() {
    return this.get('store').createRecord('api-user');
  },
});
