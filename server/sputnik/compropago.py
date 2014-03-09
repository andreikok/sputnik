from Crypto import Random
import hashlib
import datetime

__author__ = 'satosushi'

import json
import requests

from jsonschema import validate
from Crypto.Cipher import AES


class Charge:
    def __init__(self,
                  product_price,
                 customer_name,
                 customer_email,
                 customer_phone,
                 payment_type,
                 send_sms=False,
                 currency='MXN',
                 product_name='MEXBT',
                 product_id='MXN',
                 image_url='http://www.sputnik.com/BC_Logo_.png'):
        self.product_price, self.currency = product_price, currency
        self.customer_name, self.customer_email, self.customer_phone = customer_name, customer_email, customer_phone
        self.payment_type, self.send_sms = payment_type, send_sms
        self.product_name, self.product_id = product_name, product_id
        self.image_url = image_url



    @staticmethod
    def from_dict(x):
        return Charge(x['product_price'], x['customer_name'], x['customer_email'], x['payment_type'],
                      x['send_sms'], x['currency'], x['product_name'], x['product_id'], x['image_url'])



class Compropago:

    def make_public_handle(self, username):
        iv = Random.new().read(AES.block_size)
        return (iv + AES.new(self.aes_key, AES.MODE_CBC, iv).encrypt(self.pad(username))).encode('hex')

    def parse_public_handle(self, public_handle):
        cipher = public_handle.decode('hex')
        return self.unpad(
            AES.new(self.aes_key, AES.MODE_CBC, cipher[:AES.block_size]).decrypt(cipher[AES.block_size:]))

    base_URL = 'http://api.compropago.com'
    charge_URL = base_URL + '/v1/charges'
    headers = {'Accept': 'application/compropago+json',
               'Content-Type': 'application/json'}

    def __init__(self, key):
        self.key = key
        self.aes_key = hashlib.sha256('midly secret').digest()
        self.pad = lambda s: s + (AES.block_size - len(s) % AES.block_size) * chr(AES.block_size - len(s) % AES.block_size)
        self.unpad = lambda s: s[0:-ord(s[-1])]

    def create_bill(self, charge):
        charge.username = self.make_public_handle(charge.customer_name)
        r = requests.post(self.charge_URL,
                          data=json.dumps(charge.__dict__),
                          headers=self.headers, auth=(self.key, ''))


        return r.json()


    def get_bill(self, payment_id):
        r = requests.get(self.charge_URL + '/' + payment_id, auth=(self.key, ''))
        return r.json()

    def get_all(self):
        r = requests.get(self.charge_URL, auth=(self.key, ''))
        print r.text
        return r.json()

    def validate_response(self, payment_info):
        t = lambda x: dict(type=x, required=True)
        validate(payment_info, {
            'type': 'object',
            'properties': {
                'object': t('string'),
                'type': {'type': ['string', 'null']},
                'data': {'type': 'object',
                         'required': True,
                         'properties': {
                             'object': {'type': 'object',
                                        'required': True,
                                        'properties': {
                                            'id': t('string'),
                                            'short_id': t('string'),
                                            'store_mode': t('string'),
                                            'object': t('string'),
                                            'created': t('string'),
                                            'paid': t('boolean'),
                                            'amount': t('string'),
                                            'currency': t('string'),
                                            'refunded': t('boolean'),
                                            'fee': t('string'),
                                            'fee_details': {'type': 'object', 'required': True,
                                                            'properties': {
                                                                'amount': t('string'),
                                                                'currency': t('string'),
                                                                'type': t('string'),
                                                                'description': t('string'),
                                                                'application': {'type': ['string', 'null'], 'required': True},
                                                                'amount_refunded': t('number')
                                                            }
                                            },
                                            'payment_details': {'type': 'object', 'required': True,
                                                                'properties': {
                                                                    'object': t('string'),
                                                                    'store': t('string'),
                                                                    'country': t('string'),
                                                                    'product_id': t('string'),
                                                                    'product_price': t('string'),
                                                                    'product_name': t('string'),
                                                                    'image_url': t('string'),
                                                                    'success_url': t('string'),
                                                                    'customer_name': t('string'),
                                                                    'customer_email': t('string'),
                                                                    'customer_phone': t('string'),
                                                                }
                                            },
                                            'captured': t('boolean'),
                                            'failure_message': {'type': ['string', 'null'], 'required': True},
                                            'failure_code': {'type': ['string', 'null'], 'required': True},
                                            'amount_refunded': t('number'),
                                            'description': t('string'),
                                            'dispute': {'type': ['string', 'null'], 'required': True}
                                        }}}}}})
        return payment_info['data']['object']


# 'sk_test_5b82f569d4833add'
if __name__ == '__main__':
     abtest = Compropago('sk_test_5b82f569d4833add')
     bill = abtest.create_bill(Charge(11000, 'Satoshi Nakamoto', 'satoshi@bitcoin.it', '2221515801', 'OXXO'))
     print bill
    # status = abtest.get_bill(bill['payment_id'])
    # print status
    # abtest.validate_response(status)
    # #print abtest.get_all()
     pass


