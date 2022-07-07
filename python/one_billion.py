def add_new_urls(fake, coll, n):
    docs = []
    for _ in range(n):
        docs.append({
            'url': fake.url(),
            'count': fake.random_int(min=0, max=1000)
        })
    coll.insert_many(docs)
    total = coll.count_documents({})
    print(f"There are now {total} documents in the collection")

if __name__ == '__main__':
    from pymongo import MongoClient
    client = MongoClient('localhost', 27018)
    db = client['one_billion']
    # coll = db['top_k_urls']
    coll = db.create_collection('url_counts') # key: url, value: count

    from faker import Faker
    fake = Faker()

    # for _ in range(1000): # 1 billion
    #    check print ('iver gotten this far')
    # for _ in range(1000): # 1 million
    add_new_urls(fake, coll, 1000) # 1000
