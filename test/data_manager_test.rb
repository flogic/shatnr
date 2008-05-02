require File.join(File.dirname(__FILE__), 'test_helper')

class DataManagerOne < ActiveRecord::Base
  has_many :data_manager_twos
end

class DataManagerTwo < ActiveRecord::Base
  belongs_to :data_manager_one
  has_many   :data_manager_threes
end

class DataManagerThree < ActiveRecord::Base
  belongs_to :data_manager_two
  belongs_to :data_manager_three
end

class DataManagerTest < Test::Unit::TestCase

  def setup
    DataManagerOne.find(:all).map   {|d| d.destroy}
    DataManagerTwo.find(:all).map   {|d| d.destroy}
    DataManagerThree.find(:all).map {|d| d.destroy}
  end

  def test_must_load_set_a_correctly
    DataLoader.new('data_dir_a', File.join(File.dirname(__FILE__),'db'))
    assert_equal 1, DataManagerOne.count
    assert_equal 0, DataManagerTwo.count
    assert_equal 0, DataManagerThree.count
    assert_equal 'Dir A / File 1', DataManagerOne.find(:first).name
  end
  
  def test_must_load_set_b_correctly
    DataLoader.new('data_dir_b', File.join(File.dirname(__FILE__),'db'))
    assert_equal 1, DataManagerOne.count
    assert_equal 1, DataManagerTwo.count
    assert_equal 0, DataManagerThree.count
    assert_equal 'Dir B / File 1', DataManagerOne.find(:first).name
    assert_equal 'Dir B / File 2', DataManagerTwo.find(:first).name
  end
  
  def test_must_load_set_c_correctly
    DataLoader.new('data_dir_c', File.join(File.dirname(__FILE__),'db'))
    assert_equal 1, DataManagerOne.count
    assert_equal 1, DataManagerTwo.count
    assert_equal 1, DataManagerThree.count
    assert_equal 'Dir C / File 1', DataManagerOne.find(:first).name
    assert_equal 'Dir C / File 2', DataManagerTwo.find(:first).name
    assert_equal 'Dir C / File 3', DataManagerThree.find(:first).name
  end
  
  def test_must_raise_exception_on_circular_dependency
    DataManagerOne.class_eval "belongs_to :data_manager_three"
    assert_raise(RuntimeError) {DataLoader.new('data_dir_c', File.join(File.dirname(__FILE__),'db'))}
  end
  
  def test_must_raise_exception_on_bad_dir
    DataManagerOne.class_eval "belongs_to :data_manager_three"
    assert_raise(Errno::ENOENT) {DataLoader.new('x', File.join(File.dirname(__FILE__),'db'))}
  end
  
end
