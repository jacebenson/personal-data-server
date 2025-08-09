class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :bank_statements, dependent: :destroy
  has_many :investments, dependent: :destroy
  has_many :social_security_earnings, dependent: :destroy
  has_many :amazon_orders, dependent: :destroy
  has_many :email_messages, dependent: :destroy
  has_many :calendar_events, dependent: :destroy
  has_many :contacts, dependent: :destroy
end
