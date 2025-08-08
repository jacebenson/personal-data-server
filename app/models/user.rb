class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :bank_statements, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :social_security_earnings, dependent: :destroy
end
